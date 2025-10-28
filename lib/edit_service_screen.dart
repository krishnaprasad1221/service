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
  String? _selectedCategoryId;
  File? _serviceImage;
  String? _serviceImageName;
  String? _existingImageUrl;
  bool _isAvailable = true;
  
  List<String> _categories = [
    'Electrical', 'Plumbing', 'Cleaning', 'Appliance Repair', 'Tutoring', 'Beauty & Wellness', 'Other'
  ];

  final _termsController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _locationController = TextEditingController();
  final _serviceAreasController = TextEditingController();

  final Set<String> _selectedSubCategoryIds = <String>{};
  final Map<String, String> _selectedSubCategoryNames = <String, String>{};

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
    _termsController.dispose();
    _contactPhoneController.dispose();
    _websiteUrlController.dispose();
    _contactEmailController.dispose();
    _locationController.dispose();
    _serviceAreasController.dispose();
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
        final loadedCategory = data['category'] as String?;
        _selectedCategoryId = data['categoryId'] as String?; // may be null in older docs
        // Ensure dropdown has exactly one matching item for selected value
        if (loadedCategory != null && loadedCategory.isNotEmpty && !_categories.contains(loadedCategory)) {
          // Insert at the top so it's visible and selectable
          _categories = [loadedCategory, ..._categories];
        }
        // Initialize existing sub-categories (support legacy and new schema)
        final List<String> subIds = (data['subCategoryIds'] as List?)?.whereType<String>().toList() ?? <String>[];
        final String? legacySubId = data['subCategoryId'] as String?;
        if (subIds.isEmpty && legacySubId != null && legacySubId.isNotEmpty) {
          subIds.add(legacySubId);
        }
        final List<String> subNames = (data['subCategoryNames'] as List?)?.whereType<String>().toList() ?? <String>[];
        final String? legacySubName = data['subCategoryName'] as String?;
        if (subNames.isEmpty && legacySubName != null && legacySubName.isNotEmpty) {
          subNames.add(legacySubName);
        }
        for (int i = 0; i < subIds.length; i++) {
          final id = subIds[i];
          final name = (i < subNames.length) ? subNames[i] : '';
          _selectedSubCategoryIds.add(id);
          if (name.isNotEmpty) _selectedSubCategoryNames[id] = name;
        }
        final terms = data['terms'] as String?;
        final contactPhone = data['contactPhone'] as String?;
        final contactEmail = data['contactEmail'] as String?;
        final websiteUrl = data['websiteUrl'] as String?;
        final address = (data['addressDisplay'] as String?) ?? (data['locationAddress'] as String?);
        final List<String> areasList = (data['serviceAreas'] as List?)?.whereType<String>().toList() ?? <String>[];
        _termsController.text = terms ?? '';
        _contactPhoneController.text = contactPhone ?? '';
        _contactEmailController.text = contactEmail ?? '';
        _websiteUrlController.text = websiteUrl ?? '';
        _locationController.text = address ?? '';
        _serviceAreasController.text = areasList.join(', ');
        setState(() {
          _selectedCategory = loadedCategory;
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
        'categoryId': _selectedCategoryId,
        'description': _descriptionController.text.trim(),
        'serviceImageUrl': imageUrl,
        'isAvailable': _isAvailable,
        'terms': _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
        'contactEmail': _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        'websiteUrl': _websiteUrlController.text.trim().isEmpty ? null : _websiteUrlController.text.trim(),
        'addressDisplay': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'serviceAreas': _serviceAreasController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        // Legacy single + new multi-select subcategory fields
        'subCategoryId': _selectedSubCategoryIds.isNotEmpty ? _selectedSubCategoryIds.first : null,
        'subCategoryName': _selectedSubCategoryIds.isNotEmpty ? (_selectedSubCategoryNames[_selectedSubCategoryIds.first] ?? '') : null,
        'subCategoryIds': _selectedSubCategoryIds.toList(),
        'subCategoryNames': _selectedSubCategoryIds.map((id) => _selectedSubCategoryNames[id] ?? '').where((s) => s.isNotEmpty).toList(),
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
                      value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(value: category, child: Text(category));
                      }).toList(),
                      onChanged: (newValue) => setState(() {
                        // Update category name (no id mapping available in this screen)
                        _selectedCategory = newValue;
                        // Since we cannot derive categoryId from name here, null it to avoid showing wrong sub-categories
                        _selectedCategoryId = null;
                        // Clear any previously selected sub-categories
                        _selectedSubCategoryIds.clear();
                        _selectedSubCategoryNames.clear();
                      }),
                      validator: (v) => v == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildSubCategorySelector(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 3,
                      validator: (v) => v!.isEmpty ? 'Please enter a description' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _termsController,
                      decoration: const InputDecoration(labelText: 'Terms & Conditions (optional)', border: OutlineInputBorder()),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactPhoneController,
                      decoration: const InputDecoration(labelText: 'Contact Phone (optional)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactEmailController,
                      decoration: const InputDecoration(labelText: 'Contact Email (optional)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _websiteUrlController,
                      decoration: const InputDecoration(labelText: 'Website URL (optional)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Service Location / Area', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _serviceAreasController,
                      decoration: const InputDecoration(labelText: 'Service Areas (comma separated) — optional', border: OutlineInputBorder()),
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

  Widget _buildSubCategorySelector() {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return TextFormField(
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Sub-categories',
          hintText: 'No categoryId on this service. Sub-categories unavailable.',
          border: OutlineInputBorder(),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('subcategories')
        .where('categoryId', isEqualTo: _selectedCategoryId)
        .where('isActive', isEqualTo: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Text('Failed to load sub-categories');
        }
        final docs = snapshot.data?.docs ?? [];
        final entries = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final name = (data['name'] as String?) ?? 'Unnamed';
          return {'id': d.id, 'name': name};
        }).toList()
          ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

        for (final e in entries) {
          final id = e['id'] as String;
          final name = e['name'] as String;
          if (_selectedSubCategoryIds.contains(id) && (_selectedSubCategoryNames[id] == null || _selectedSubCategoryNames[id]!.isEmpty)) {
            _selectedSubCategoryNames[id] = name;
          }
        }

        return InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Sub-categories',
            border: OutlineInputBorder(),
          ),
          child: entries.isEmpty
              ? const Text('No sub-categories found for this category', style: TextStyle(color: Colors.grey))
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: entries.map((e) {
                    final id = e['id'] as String;
                    final name = e['name'] as String;
                    final selected = _selectedSubCategoryIds.contains(id);
                    return FilterChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSubCategoryIds.add(id);
                            _selectedSubCategoryNames[id] = name;
                          } else {
                            _selectedSubCategoryIds.remove(id);
                            _selectedSubCategoryNames.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}