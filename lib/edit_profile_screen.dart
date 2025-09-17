// lib/edit_profile_screen.dart

import 'dart:io'; // <--- FIXED
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:serviceprovider/waiting_for_approval_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isCompletingProfile;
  const EditProfileScreen({Key? key, this.isCompletingProfile = false})
      : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _addressController = TextEditingController();
  final _serviceFieldController = TextEditingController();
  File? _documentImage;
  String? _documentFileName;

  @override
  void dispose() {
    _addressController.dispose();
    _serviceFieldController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _documentImage = File(pickedFile.path);
        _documentFileName = pickedFile.name;
      });
    }
  }

  Future<void> _saveAndSubmitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_documentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload your legal document for verification.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      final ref = FirebaseStorage.instance
          .ref()
          .child('legal_documents')
          .child('$uid/${_documentFileName!}');
      await ref.putFile(_documentImage!);
      final documentUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'address': _addressController.text.trim(),
        'serviceField': _serviceFieldController.text.trim(),
        'documentUrl': documentUrl,
        'isProfileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WaitingForApprovalScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to submit profile: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... Your build method UI code remains the same ...
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCompletingProfile
            ? 'Complete Your Profile'
            : 'Edit Profile'),
        automaticallyImplyLeading: !widget.isCompletingProfile,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isCompletingProfile)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    "Welcome! Please provide these final details to submit your profile for review.",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                    labelText: 'Full Address', border: OutlineInputBorder()),
                validator: (v) =>
                    v!.isEmpty ? 'Please enter your address' : null,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serviceFieldController,
                decoration: const InputDecoration(
                    labelText: 'Field of Service (e.g., Electrician, Plumber)',
                    border: OutlineInputBorder()),
                validator: (v) =>
                    v!.isEmpty ? 'Please enter your service field' : null,
              ),
              const SizedBox(height: 24),
              const Text("Upload a Legal Document",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Text(
                  "(e.g., Aadhaar Card, PAN Card) for verification.",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(_documentFileName ?? 'Select Document'),
                onPressed: _pickDocument,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              if (_documentImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(_documentImage!,
                      height: 150, fit: BoxFit.contain),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveAndSubmitProfile,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save and Submit for Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}