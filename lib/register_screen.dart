// lib/register_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  File? _profileImage;
  String? _selectedRole;
  final List<String> _roles = ["User", "Service Provider"];

  bool _verificationEmailSent = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _profileImage = File(picked.path);
      });
    }
  }

  Future<void> _registerAndSendVerificationEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_profileImage == null) {
      Fluttertoast.showToast(msg: "Please select a profile image.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await userCredential.user?.sendEmailVerification();

      setState(() {
        _verificationEmailSent = true;
        _isLoading = false;
      });

      Fluttertoast.showToast(
        msg: "Verification email sent! Please check your inbox. 📧",
        backgroundColor: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Registration Failed";
      if (e.code == 'email-already-in-use') {
        errorMessage = "This email is already registered.";
      } else if (e.code == 'weak-password') {
        errorMessage = "The password is too weak.";
      }
      Fluttertoast.showToast(msg: errorMessage, backgroundColor: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  // UPDATED METHOD: This now includes the correct approval status fields.
  // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
  Future<void> _checkEmailVerificationAndCompleteProfile() async {
    setState(() => _isLoading = true);

    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      try {
        final userId = user.uid;
        final profileImageUrl = await _uploadProfileImage(userId);

        Map<String, dynamic> userData = {
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'profileImageUrl': profileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'isEmailVerified': true,
        };

        // Set the correct flags for the approval workflow
        if (_selectedRole == 'Service Provider') {
          userData.addAll({
            'isProfileComplete': false, // Must complete profile after login
            'isApproved': false,       // Admin must approve
            'isRejected': false,       // Default rejection status
          });
        } else {
          // Regular users are considered complete on registration
          userData['isProfileComplete'] = true;
        }

        await FirebaseFirestore.instance.collection('users').doc(userId).set(userData);

        String successMessage = _selectedRole == 'Service Provider'
            ? "Registration complete! Please log in to finish your profile."
            : "Email verified! Registration complete. Please log in.";

        Fluttertoast.showToast(
          msg: successMessage,
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false);
        }
      } catch (e) {
        Fluttertoast.showToast(
            msg: "Failed to save profile: $e", backgroundColor: Colors.red);
      }
    } else {
      Fluttertoast.showToast(
        msg: "Email not yet verified. Please click the link in your inbox.",
        backgroundColor: Colors.orange,
      );
    }
    setState(() => _isLoading = false);
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_profileImage == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');
      await ref.putFile(_profileImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to upload profile image: $e");
      return null;
    }
  }
  
  // --- The rest of your UI code (build methods) remains the same ---
  // (I've omitted it for brevity, just use your existing build methods)

  @override
  Widget build(BuildContext context) {
    // ... your existing build method ...
     return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Form(
              key: _formKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _verificationEmailSent
                    ? _buildVerificationSentScreen()
                    : _buildRegistrationForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    // ... your existing _buildRegistrationForm method ...
      return Column(
      key: const ValueKey('registrationForm'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
            text: const TextSpan(children: [
          TextSpan(
              text: "Serv",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
          TextSpan(
              text: "Sphere",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black))
        ])),
        const SizedBox(height: 20),
        Center(child: _buildProfileImagePicker()),
        const SizedBox(height: 20),
        _buildTextField(
            label: "User Name *",
            controller: _usernameController,
            validator: (v) => v!.isEmpty ? "Enter username" : null),
        const SizedBox(height: 10),
        _buildTextField(
            label: "Phone",
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: (v) => null),
        const SizedBox(height: 10),
        _buildTextField(
            label: "Email *",
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                !(v!.contains('@')) ? "Enter a valid email" : null),
        const SizedBox(height: 10),
        _buildTextField(
            label: "Password *",
            controller: _passwordController,
            obscureText: true,
            validator: (v) => v!.length < 6
                ? "Password must be at least 6 characters"
                : null),
        const SizedBox(height: 10),
        _buildTextField(
            label: "Confirm Password *",
            controller: _confirmPasswordController,
            obscureText: true,
            validator: (v) =>
                v != _passwordController.text ? "Passwords do not match" : null),
        const SizedBox(height: 10),
        _buildRoleDropdown(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800]),
                  onPressed: _registerAndSendVerificationEmail,
                  child: const Text("Verify Email & Continue"),
                ),
        ),
        const SizedBox(height: 15),
        _buildLoginLink(),
      ],
    );
  }

  Widget _buildVerificationSentScreen() {
    // ... your existing _buildVerificationSentScreen method ...
      return Column(
      key: const ValueKey('verificationScreen'),
      children: [
        const Icon(Icons.email_outlined, color: Colors.green, size: 80),
        const SizedBox(height: 20),
        const Text("Check Your Email",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Text(
          "We've sent a verification link to:\n${_emailController.text.trim()}",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
        const SizedBox(height: 10),
        Text(
          "Click the link to verify your account, then come back and press the button below.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _checkEmailVerificationAndCompleteProfile,
                  child: const Text("I Have Verified, Complete Registration"),
                ),
        ),
        const SizedBox(height: 15),
        TextButton(
          onPressed: () => setState(() => _verificationEmailSent = false),
          child: const Text("Go Back & Change Email"),
        ),
      ],
    );
  }

  Widget _buildProfileImagePicker() {
    // ... your existing _buildProfileImagePicker method ...
      return GestureDetector(
      onTap: _pickImage,
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[300],
        backgroundImage:
            _profileImage != null ? FileImage(_profileImage!) : null,
        child: _profileImage == null
            ? const Icon(Icons.camera_alt, size: 30)
            : null,
      ),
    );
  }

  Widget _buildTextField(
      {required String label,
      required TextEditingController controller,
      bool obscureText = false,
      TextInputType keyboardType = TextInputType.text,
      required String? Function(String?)? validator}) {
    // ... your existing _buildTextField method ...
       return TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
        validator: validator);
  }

  Widget _buildRoleDropdown() {
    // ... your existing _buildRoleDropdown method ...
      return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      items: _roles
          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
          .toList(),
      onChanged: (value) => setState(() => _selectedRole = value),
      decoration: InputDecoration(
          labelText: "Select Role *",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true),
      validator: (value) => value == null ? "Please select a role" : null,
    );
  }

  Widget _buildLoginLink() {
    // ... your existing _buildLoginLink method ...
      return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account? "),
        GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: const Text("Login",
              style:
                  TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}