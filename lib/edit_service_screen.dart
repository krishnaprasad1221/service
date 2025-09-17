// lib/edit_service_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditServiceScreen extends StatefulWidget {
  final QueryDocumentSnapshot service;

  const EditServiceScreen({super.key, required this.service});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late final TextEditingController _serviceNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _basePriceController;
  late final TextEditingController _locationController;

  String? _selectedCategory;
  File? _serviceImage;
  String? _existingImageUrl;
  bool? _isAvailable;
  String? _status;

  final List<String> _categories = [
    'Home Services', 'IT Support', 'Beauty', 'Tutoring', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.service.data() as Map<String, dynamic>;
    _serviceNameController = TextEditingController(text: data['serviceName']);
    _descriptionController = TextEditingController(text: data['description']);
    _basePriceController = TextEditingController(text: data['basePrice'].toString());
    _locationController = TextEditingController(text: data['location']);
    _selectedCategory = data['category'];
    _isAvailable = data['isAvailable'];
    _status = data['status'];
    _existingImageUrl = data['serviceImageUrl'];
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _serviceImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    try {
      String imageUrl = _existingImageUrl!;
      if (_serviceImage != null) {
        final user = FirebaseAuth.instance.currentUser;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('service_images')
            .child('${user!.uid}_${DateTime.now().toIso8601String()}.jpg');
        await storageRef.putFile(_serviceImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('services').doc(widget.service.id).update({
        'serviceName': _serviceNameController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'basePrice': double.tryParse(_basePriceController.text) ?? 0.0,
        'isAvailable': _isAvailable,
        'location': _locationController.text.trim(),
        'serviceImageUrl': imageUrl,
        'status': _status,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service updated successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update service: $e'), backgroundColor: Colors.red),
      );
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Service'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _serviceNameController,
                decoration: const InputDecoration(labelText: 'Service Name', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a service name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(value: category, child: Text(category));
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedCategory = newValue),
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Short Description', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _basePriceController,
                decoration: const InputDecoration(labelText: 'Base Price', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Service Location / City', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a location' : null,
              ),
              const SizedBox(height: 24),
              Text('Service Image', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: _serviceImage != null
                        ? Image.file(_serviceImage!, fit: BoxFit.cover)
                        : Image.network(_existingImageUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Available for booking'),
                value: _isAvailable ?? true,
                onChanged: (val) => setState(() => _isAvailable = val),
              ),
              SwitchListTile(
                title: const Text('Publish Immediately'),
                value: _status == 'published',
                onChanged: (val) => setState(() => _status = val ? 'published' : 'draft'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateService,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('Update Service'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}