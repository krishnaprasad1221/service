// lib/user_edit_profile.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class UserEditProfileScreen extends StatefulWidget {
  const UserEditProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserEditProfileScreen> createState() => _UserEditProfileScreenState();
}

class _UserEditProfileScreenState extends State<UserEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFetchingLocation = false;

  // ▼▼▼ ADDED: Controller for username ▼▼▼
  final _usernameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  File? _profileImage;
  String? _existingImageUrl;
  GeoPoint? _currentGeoPoint;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    // ▼▼▼ ADDED: Dispose the new controller ▼▼▼
    _usernameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Fetches the current user's data from Firestore to pre-fill the form.
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          // ▼▼▼ ADDED: Load username into its controller ▼▼▼
          _usernameController.text = data['username'] ?? '';
          _addressController.text = data['address'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? user.email ?? '';
          _existingImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handles picking a new profile photo from the gallery.
  Future<void> _pickProfileImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  /// Gets the user's current GPS location, converts it to an address,
  /// and updates the address field.
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are denied.');
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        // Create a comprehensive address string
        final address =
            "${place.street}, ${place.locality}, ${place.postalCode}, ${place.administrativeArea}";
        _addressController.text = address;
        // Store the coordinates to be saved
        _currentGeoPoint = GeoPoint(position.latitude, position.longitude);
      }
    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not get location: $e'),
              backgroundColor: Colors.red),
        );
       }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  /// Saves the updated profile data to Firebase.
  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;
      String? profileImageUrl = _existingImageUrl;

      if (_profileImage != null) {
        final profileRef =
            FirebaseStorage.instance.ref().child('profile_images').child('$uid.jpg');
        await profileRef.putFile(_profileImage!);
        profileImageUrl = await profileRef.getDownloadURL();
      }

      final Map<String, dynamic> dataToUpdate = {
        // ▼▼▼ ADDED: Save the updated username ▼▼▼
        'username': _usernameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'profileImageUrl': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_currentGeoPoint != null) {
        dataToUpdate['location'] = _currentGeoPoint;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(dataToUpdate, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!)
                                : (_existingImageUrl != null
                                    ? NetworkImage(_existingImageUrl!)
                                    : null) as ImageProvider?,
                            child: _profileImage == null &&
                                    _existingImageUrl == null
                                ? Icon(Icons.person,
                                    size: 60, color: Colors.grey.shade400)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickProfileImage,
                              child: const CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.deepPurple,
                                child: Icon(Icons.camera_alt,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // ▼▼▼ ADDED: TextFormField for Username ▼▼▼
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v!.trim().isEmpty ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 16),
                    // ▼▼▼ UPDATED: Email field is now read-only ▼▼▼
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Email Address (Cannot change)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email_outlined),
                        fillColor: Colors.grey.shade200,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined)),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? 'Enter your phone number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined)),
                      validator: (v) =>
                          v!.isEmpty ? 'Please enter your address' : null,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: _isFetchingLocation
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      label: const Text('Update with Live Location'),
                      onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfileChanges,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white),
                      child: _isSaving
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}