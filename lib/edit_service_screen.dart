// lib/edit_service_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditServiceScreen extends StatefulWidget {
  final String serviceId;
  const EditServiceScreen({super.key, required this.serviceId});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isUploading = false;

  final _serviceNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  // ▼▼▼▼▼ PRICE CONTROLLER REMOVED ▼▼▼▼▼
  // final _priceController = TextEditingController();
  // ▲▲▲▲▲ PRICE CONTROLLER REMOVED ▲▲▲▲▲

  String? _selectedCategory;
  File? _serviceImage;
  String? _serviceImageName;
  String? _existingImageUrl;
  bool _isAvailable = true;
  
  final List<String> _categories = [
    'Electrical', 'Plumbing', 'Cleaning', 'Appliance Repair', 'Tutoring', 'Beauty & Wellness', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadServiceData();
  }

  // Dispose controllers for better memory management
  @override
  void dispose() {
    _serviceNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadServiceData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('services').doc(widget.serviceId).get();
      final data = doc.data();
      if (data != null) {
        _serviceNameController.text = data['serviceName'];
        _descriptionController.text = data['description'];
        // ▼▼▼▼▼ PRICE LOADING LOGIC REMOVED ▼▼▼▼▼
        // _priceController.text = data['price'].toString();
        // ▲▲▲▲▲ PRICE LOADING LOGIC REMOVED ▲▲▲▲▲
        setState(() {
          _selectedCategory = data['category'];
          _isAvailable = data['isAvailable'];
          _existingImageUrl = data['serviceImageUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load service data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _serviceImage = File(pickedFile.path);
        _serviceImageName = pickedFile.name;
      });
    }
  }

  Future<void> _updateService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      String imageUrl = _existingImageUrl!;
      
      if (_serviceImage != null) {
        final user = FirebaseAuth.instance.currentUser!;
        final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
        final storageRef = FirebaseStorage.instance.ref().child('service_images').child(fileName);

        await storageRef.putFile(_serviceImage!);
        imageUrl = await storageRef.getDownloadURL();

        if (_existingImageUrl != null) {
          await FirebaseStorage.instance.refFromURL(_existingImageUrl!).delete();
        }
      }

      await FirebaseFirestore.instance.collection('services').doc(widget.serviceId).update({
        'serviceName': _serviceNameController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'serviceImageUrl': imageUrl,
        'isAvailable': _isAvailable,
        // ▼▼▼▼▼ PRICE UPDATE LOGIC REMOVED ▼▼▼▼▼
        // 'price': double.tryParse(_priceController.text) ?? 0.0,
        // ▲▲▲▲▲ PRICE UPDATE LOGIC REMOVED ▲▲▲▲▲
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service updated successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Service'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _serviceNameController,
                      decoration: const InputDecoration(labelText: 'Service Name', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Please enter a service name' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (newValue) => setState(() => _selectedCategory = newValue),
                      validator: (v) => v == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 3,
                      validator: (v) => v!.isEmpty ? 'Please enter a description' : null,
                    ),
                    
                    // ▼▼▼▼▼ PRICE FORM FIELD REMOVED ▼▼▼▼▼
                    // const SizedBox(height: 16),
                    // TextFormField(
                    //   controller: _priceController,
                    //   ...
                    // ),
                    // ▲▲▲▲▲ PRICE FORM FIELD REMOVED ▲▲▲▲▲

                    const SizedBox(height: 24),
                    _serviceImage == null
                        ? (_existingImageUrl != null ? Image.network(_existingImageUrl!) : Container())
                        : Image.file(_serviceImage!),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_serviceImageName ?? 'Change Service Photo'),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Available for booking'),
                      value: _isAvailable,
                      onChanged: (bool value) => setState(() => _isAvailable = value),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _isUploading ? null : _updateService,
                      child: _isUploading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Text('Update Service'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}