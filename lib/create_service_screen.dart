// lib/create_service_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  // ▼▼▼▼▼ REMOVED PRICE CONTROLLER ▼▼▼▼▼
  // final _priceController = TextEditingController();
  // ▲▲▲▲▲ REMOVED PRICE CONTROLLER ▲▲▲▲▲
  final _locationController = TextEditingController();

  String? _selectedCategory;
  File? _serviceImage;
  String? _serviceImageName;
  bool _isAvailable = true;
  final List<String> _categories = [
    'Electrical', 'Plumbing', 'Cleaning', 'Appliance Repair', 'Tutoring', 'Beauty & Wellness', 'Other'
  ];

  Position? _currentPosition;

  @override
  void dispose() {
    _serviceNameController.dispose();
    _descriptionController.dispose();
    // ▼▼▼▼▼ REMOVED PRICE CONTROLLER FROM DISPOSE ▼▼▼▼▼
    // _priceController.dispose();
    // ▲▲▲▲▲ REMOVED PRICE CONTROLLER FROM DISPOSE ▲▲▲▲▲
    _locationController.dispose();
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

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permissions are denied')));
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permissions are permanently denied, we cannot request permissions.')));
        setState(() => _isFetchingLocation = false);
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);
      
      Placemark place = placemarks[0];
      String address = '${place.locality}, ${place.postalCode}, ${place.country}';
      _locationController.text = address;

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if(mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _createService() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a service photo.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      
      final storageRef = FirebaseStorage.instance.ref().child('service_images').child(fileName);
      await storageRef.putFile(_serviceImage!);
      final imageUrl = await storageRef.getDownloadURL();

      // ▼▼▼▼▼ FIRESTORE DOCUMENT UPDATED ▼▼▼▼▼
      await FirebaseFirestore.instance.collection('services').add({
        'providerId': user.uid,
        'providerName': user.displayName ?? 'N/A',
        'serviceName': _serviceNameController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'serviceImageUrl': imageUrl,
        'isAvailable': _isAvailable,
        'createdAt': FieldValue.serverTimestamp(),
        // 'price' field removed
        'locationAddress': _locationController.text.trim(),
        'locationGeoPoint': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
      });
      // ▲▲▲▲▲ FIRESTORE DOCUMENT UPDATED ▲▲▲▲▲

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service created successfully!'), backgroundColor: Colors.green)
      );
      Navigator.of(context).pop();

    } on FirebaseException catch (e) {
      String errorMessage = "An error occurred. Please try again.";
      if (e.code == 'permission-denied') {
        errorMessage = "Permission Denied. Your account may not be approved to create services.";
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
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
                decoration: const InputDecoration(labelText: 'Short Description', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),

              // ▼▼▼▼▼ PRICE WIDGET REMOVED ▼▼▼▼▼
              // The TextFormField for price has been removed from here.
              // ▲▲▲▲▲ PRICE WIDGET REMOVED ▲▲▲▲▲
              
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
                validator: (v) => v!.isEmpty ? 'Please enter a location' : null,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: Text(_serviceImageName ?? 'Upload Service Photo'),
                onPressed: _pickImage,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Available for booking'),
                value: _isAvailable,
                onChanged: (bool value) => setState(() => _isAvailable = value),
                secondary: Icon(_isAvailable ? Icons.toggle_on : Icons.toggle_off, color: Theme.of(context).primaryColor, size: 40),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createService,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : const Text('Create Service'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}