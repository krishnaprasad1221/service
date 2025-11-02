// lib/create_service_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'service_preview_screen.dart';

class CreateServiceScreen extends StatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  State<CreateServiceScreen> createState() => _CreateServiceScreenState();
}

class _CreateServiceScreenState extends State<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetchingLocation = false;

  final _serviceNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  // final _priceController = TextEditingController(); // removed
  final _locationController = TextEditingController();
  final _serviceAreasController = TextEditingController();
  final _termsController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _contactEmailController = TextEditingController();

  // Category selection
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  File? _serviceImage;
  String? _serviceImageName;
  bool _isAvailable = true;
  Position? _currentPosition;

  // Location/Type

  // Sub-category selection
  final Set<String> _selectedSubCategoryIds = <String>{};
  final Map<String, String> _selectedSubCategoryNames = <String, String>{};
  final TextEditingController _subCategoryNameController = TextEditingController();

  @override
  void dispose() {
    _serviceNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _serviceAreasController.dispose();
    _termsController.dispose();
    _contactPhoneController.dispose();
    _websiteUrlController.dispose();
    _contactEmailController.dispose();
    _subCategoryNameController.dispose();
    super.dispose();
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

  // Simple Geohash encoder (precision 9) to avoid extra dependencies
  String? _encodeGeohash(double? latitude, double? longitude, {int precision = 9}) {
    if (latitude == null || longitude == null) return null;
    const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    double latMin = -90.0, latMax = 90.0, lonMin = -180.0, lonMax = 180.0;
    bool isLon = true;
    int bit = 0, ch = 0;
    StringBuffer geohash = StringBuffer();
    while (geohash.length < precision) {
      if (isLon) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude > mid) {
          ch |= 1 << (4 - bit);
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude > mid) {
          ch |= 1 << (4 - bit);
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      isLon = !isLon;
      if (bit < 4) {
        bit++;
      } else {
        geohash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return geohash.toString();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
        setState(() => _isFetchingLocation = false);
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      Placemark place = placemarks[0];
      String address = '${place.locality}, ${place.postalCode}, ${place.country}';
      _locationController.text = address;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _createService() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a service photo.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final storageRef = FirebaseStorage.instance.ref().child('service_images').child(fileName);
      await storageRef.putFile(_serviceImage!);
      final imageUrl = await storageRef.getDownloadURL();

      // Prepare multi-select subcategory arrays and legacy single fields
      final List<String> subIds = _selectedSubCategoryIds.toList();
      final List<String> subNames = _selectedSubCategoryIds
          .map((id) => _selectedSubCategoryNames[id] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final String? legacySubId = subIds.isNotEmpty ? subIds.first : null;
      final String? legacySubName = subNames.isNotEmpty ? subNames.first : null;

      await FirebaseFirestore.instance.collection('services').add({
        'providerId': user.uid,
        'providerName': user.displayName ?? 'N/A',
        'serviceName': _serviceNameController.text.trim(),
        // Keep existing 'category' field for compatibility
        'category': _selectedCategoryName,
        // New structured fields
        'categoryId': _selectedCategoryId,
        'categoryName': _selectedCategoryName,
        // Legacy single fields for backward compatibility
        'subCategoryId': legacySubId,
        'subCategoryName': legacySubName,
        // New multi-select fields
        'subCategoryIds': subIds,
        'subCategoryNames': subNames,
        'description': _descriptionController.text.trim(),
        'terms': _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim().isEmpty ? null : _contactPhoneController.text.trim(),
        'contactEmail': _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        'websiteUrl': _websiteUrlController.text.trim().isEmpty ? null : _websiteUrlController.text.trim(),
        'serviceImageUrl': imageUrl,
        'isAvailable': _isAvailable,
        'createdAt': FieldValue.serverTimestamp(),
        // Legacy/Existing fields kept
        'locationAddress': _locationController.text.trim(),
        'locationGeoPoint': _currentPosition != null ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude) : null,
        // New Location schema
        'lat': _currentPosition?.latitude,
        'lng': _currentPosition?.longitude,
        'geohash': _encodeGeohash(_currentPosition?.latitude, _currentPosition?.longitude),
        'serviceAreas': _serviceAreasController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'addressDisplay': _locationController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service created successfully!'), backgroundColor: Colors.green));
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      String errorMessage = "An error occurred. Please try again.";
      if (e.code == 'permission-denied') {
        errorMessage = "Permission Denied. Your account may not be approved to create services.";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('isActive', isEqualTo: true)
          .snapshots(),
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
          return const Text('Failed to load categories');
        }
        final docs = snapshot.data?.docs ?? [];
        final entries = docs
            .map((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] as String?) ?? 'Unnamed';
              return {'id': d.id, 'name': name};
            })
            .toList();
        // Sort client-side by name
        entries.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
        if (entries.isEmpty) {
          return TextFormField(
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'No categories available. Contact admin.',
              border: OutlineInputBorder(),
            ),
            validator: (_) => 'No categories available',
          );
        }
        return DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
          items: entries.map((e) {
            return DropdownMenuItem<String>(value: e['id'] as String, child: Text(e['name'] as String));
          }).toList(),
          onChanged: (newId) {
            if (newId == null) return;
            final match = entries.firstWhere((e) => e['id'] == newId);
            setState(() {
              _selectedCategoryId = newId;
              _selectedCategoryName = match['name'] as String;
              // reset subcategory when category changes
              _selectedSubCategoryIds.clear();
              _selectedSubCategoryNames.clear();
            });
          },
          validator: (v) => v == null ? 'Please select a category' : null,
        );
      },
    );
  }

  Widget _buildSubCategorySelector() {
    if (_selectedCategoryId == null) {
      return TextFormField(
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Sub-category',
          hintText: 'Select a category first',
          border: OutlineInputBorder(),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subcategories')
          .where('categoryId', isEqualTo: _selectedCategoryId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
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
        final entries = docs
            .map((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] as String?) ?? 'Unnamed';
              return {'id': d.id, 'name': name};
            })
            .toList();
        entries.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
        return FormField<bool>(
          validator: (_) => entries.isNotEmpty && _selectedSubCategoryIds.isEmpty
              ? 'Please select at least one sub-category'
              : null,
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sub-categories',
                    border: OutlineInputBorder(),
                  ),
                  child: entries.isEmpty
                      ? const Text('No sub-categories. Use + to add one.', style: TextStyle(color: Colors.grey))
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
                              onSelected: (bool value) {
                                setState(() {
                                  if (value) {
                                    _selectedSubCategoryIds.add(id);
                                    _selectedSubCategoryNames[id] = name;
                                  } else {
                                    _selectedSubCategoryIds.remove(id);
                                    _selectedSubCategoryNames.remove(id);
                                  }
                                });
                                state.didChange(true);
                              },
                            );
                          }).toList(),
                        ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(state.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addSubCategoryInline() async {
    if (_selectedCategoryId == null || _selectedCategoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a category first')));
      return;
    }

    final formKey = GlobalKey<FormState>();
    _subCategoryNameController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Sub-category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _subCategoryNameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Sub-category name', border: OutlineInputBorder()),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter a name';
              if (v.trim().length < 2) return 'Minimum 2 characters';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = _subCategoryNameController.text.trim();

              bool canProceed = true;
              try {
                // De-dupe within the same category (best-effort)
                final existing = await FirebaseFirestore.instance
                    .collection('subcategories')
                    .where('categoryId', isEqualTo: _selectedCategoryId)
                    .where('name_lc', isEqualTo: name.toLowerCase())
                    .limit(1)
                    .get();
                if (existing.docs.isNotEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sub-category already exists')));
                  canProceed = false;
                }
              } on FirebaseException catch (e) {
                // If rules block read temporarily, skip de-dupe but still allow create
                if (e.code == 'permission-denied') {
                  canProceed = true;
                } else {
                  rethrow;
                }
              }

              if (!canProceed) return;

              try {
                final doc = await FirebaseFirestore.instance.collection('subcategories').add({
                  'name': name,
                  'name_lc': name.toLowerCase(),
                  'categoryId': _selectedCategoryId,
                  'categoryName': _selectedCategoryName,
                  'isActive': true,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                });

                setState(() {
                  _selectedSubCategoryIds.add(doc.id);
                  _selectedSubCategoryNames[doc.id] = name;
                });
                if (mounted) Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sub-category created'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Service'),
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
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Please enter a service name';
                  if (t.length < 3) return 'Minimum 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              
              const SizedBox(height: 16),
              // Sub-category row: chips multi-select + add button
              Row(
                children: [
                  Expanded(child: _buildSubCategorySelector()),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Add Sub-category',
                    child: OutlinedButton.icon(
                      onPressed: _addSubCategoryInline,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Short Description', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Please enter a description';
                  if (t.length < 10) return 'Minimum 10 characters';
                  return null;
                },
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final digits = t.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10 || digits.length > 15) {
                    return 'Enter a valid phone (10-15 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(labelText: 'Contact Email (optional)', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRe.hasMatch(t)) return 'Enter a valid email';
                  return null;
                },
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
                decoration: InputDecoration(
                  labelText: 'Service Location / Area',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isFetchingLocation
                      ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _getCurrentLocation,
                          tooltip: 'Get Current Location',
                        ),
                ),
                validator: (v) {
                  return (v == null || v.isEmpty) ? 'Please enter a location' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serviceAreasController,
                decoration: const InputDecoration(
                  labelText: 'Service Areas (comma separated cities/areas) — optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: Text(_serviceImageName ?? 'Upload Service Photo'),
                onPressed: _pickImage,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Available for booking'),
                value: _isAvailable,
                onChanged: (bool value) => setState(() => _isAvailable = value),
                secondary: Icon(_isAvailable ? Icons.toggle_on : Icons.toggle_off, color: Theme.of(context).primaryColor, size: 40),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final previewData = {
                          'serviceName': _serviceNameController.text.trim(),
                          'categoryName': _selectedCategoryName,
                          'subCategoryNames': _selectedSubCategoryNames.values.toList(),
                          'description': _descriptionController.text.trim(),
                          'terms': _termsController.text.trim(),
                          'contactPhone': _contactPhoneController.text.trim(),
                          'contactEmail': _contactEmailController.text.trim(),
                          'websiteUrl': _websiteUrlController.text.trim(),
                          'addressDisplay': _locationController.text.trim(),
                          'imageFilePath': _serviceImage?.path,
                        };
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ServicePreviewScreen(data: previewData),
                          ),
                        );
                      },
                      child: const Text('Preview for Customer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createService,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                          : const Text('Create Service'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}