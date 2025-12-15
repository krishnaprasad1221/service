 import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
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
  String? _selectedRole;
  final List<String> _roles = ["Customer", "Service Provider"];

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  bool _verificationEmailSent = false;
  Timer? _verificationTimer;
  bool _isResendingEmail = false;

  File? _profileImageFile;

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Picture'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 50, // Compress image to save space
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to pick image: $e");
    }
  }

  Future<String?> _uploadProfileImage(File image, String userId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask.whenComplete(() => {});

      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to upload profile picture. Continuing without it.",
        backgroundColor: Colors.orange,
      );
      return null;
    }
  }

  Future<void> _registerAndSendVerificationEmail() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) {
      if (_selectedRole == null) setState(() {});
      Fluttertoast.showToast(
          msg: "Please fix the errors and fill all required fields.");
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

      _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _checkEmailVerificationAndCompleteProfile(isAutoCheck: true);
      });

      Fluttertoast.showToast(
        msg: "Verification email sent! Please check your inbox.",
        backgroundColor: Color(0xFF10B981),
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
    } catch (e) {
      Fluttertoast.showToast(
          msg: "An unknown error occurred: $e", backgroundColor: Colors.red);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkEmailVerificationAndCompleteProfile(
      {bool isAutoCheck = false}) async {
    if (!isAutoCheck && mounted) {
      setState(() => _isLoading = true);
    }

    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      _verificationTimer?.cancel();

      if (mounted) setState(() => _isLoading = true);

      try {
        final userId = user.uid;
        String? profileImageUrl;

        if (_profileImageFile != null) {
          profileImageUrl = await _uploadProfileImage(_profileImageFile!, userId);
        }

        Map<String, dynamic> userData = {
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'profileImageUrl': profileImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'isEmailVerified': true,
        };

        if (_selectedRole == 'Service Provider') {
          userData.addAll({
            'isProfileComplete': false,
            'isApproved': false,
            'isRejected': false,
          });
        } else {
          userData['isProfileComplete'] = true;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set(userData);

        await FirebaseAuth.instance.signOut();

        Fluttertoast.showToast(
          msg: "Email verified! Registration complete. Please log in.",
          backgroundColor: Color(0xFF10B981),
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
          msg: "Error saving profile. Please contact support.",
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (!isAutoCheck) {
      Fluttertoast.showToast(
        msg: "Email not yet verified. Please click the link in your inbox.",
        backgroundColor: Colors.orange,
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResendingEmail) return;
    setState(() => _isResendingEmail = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      Fluttertoast.showToast(
        msg: "Verification email sent again.",
        backgroundColor: Color(0xFF10B981),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to resend email: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isResendingEmail = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
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
    return Container(
      key: const ValueKey('registrationForm'),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(
                "Create Account", "Get started by filling out the form below"),
            const SizedBox(height: 24),
            _buildProfileImagePicker(),
            const SizedBox(height: 24),
            _buildRoleSelector(),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _usernameController,
                label: "Full Name",
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (RegExp(r'[^a-zA-Z\s]').hasMatch(value)) {
                    return 'Name can only contain letters and spaces';
                  }
                  if (value.contains('  ')) {
                    return 'Name cannot contain multiple spaces';
                  }
                  return null;
                }),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (RegExp(r'[^0-9]').hasMatch(value)) {
                    return 'Enter a valid phone number (digits only)';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  return null;
                }),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _emailController,
                label: "Email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (RegExp(r'^[0-9]').hasMatch(value)) {
                    return 'Email cannot start with a number';
                  }
                  if (RegExp(r'^[^a-zA-Z0-9]').hasMatch(value)) {
                    return 'Email cannot start with a special character';
                  }
                  if (!RegExp(
                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                      .hasMatch(value)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                }),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: _isPasswordVisible,
                onVisibilityToggle: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'^[A-Z]').hasMatch(value)) {
                    return 'Password must start with a capital letter';
                  }
                  if (RegExp(r'^[^a-zA-Z0-9]').hasMatch(value)) {
                    return 'Password cannot start with a special character';
                  }
                  return null;
                }),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _confirmPasswordController,
                label: "Confirm Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: _isConfirmPasswordVisible,
                onVisibilityToggle: () => setState(
                    () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                validator: (v) =>
                    v != _passwordController.text ? "Passwords do not match" : null),
            const SizedBox(height: 24),
            _buildRegisterButton(),
            const SizedBox(height: 24),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey.shade300,
          backgroundImage:
              _profileImageFile != null ? FileImage(_profileImageFile!) : null,
          child: _profileImageFile == null
              ? Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.grey.shade600,
                )
              : null,
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            onPressed: _pickImage,
          ),
        )
      ],
    );
  }

  Widget _buildVerificationSentScreen() {
    return Container(
        key: const ValueKey('verificationScreen'),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_outlined,
                color: Colors.green, size: 80),
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
              "Click the link, then return here. We're checking automatically.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading
                    ? null
                    : () => _checkEmailVerificationAndCompleteProfile(),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ))
                    : const Text("I Have Verified, Continue",
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    _verificationTimer?.cancel();
                    setState(() => _verificationEmailSent = false);
                  },
                  child: const Text("Change Email"),
                ),
                TextButton(
                  onPressed: _isResendingEmail ? null : _resendVerificationEmail,
                  child: _isResendingEmail
                      ? const Text("Sending...")
                      : const Text("Resend Link"),
                ),
              ],
            ),
          ],
        ));
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("I am a...",
            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: _roles.map((role) {
            final bool isSelected = _selectedRole == role;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedRole = role),
                child: Container(
                  margin: EdgeInsets.only(
                      right: role == _roles.first ? 8.0 : 0.0,
                      left: role == _roles.last ? 8.0 : 0.0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF7C3AED) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            isSelected ? Color(0xFF7C3AED) : Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Text(
                      role,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_formKey.currentState?.validate() == false && _selectedRole == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text("Please select a role",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12)),
          )
      ],
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool isPassword = false,
      bool isPasswordVisible = false,
      VoidCallback? onVisibilityToggle,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword && !isPasswordVisible,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(isPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: onVisibilityToggle,
              )
            : null,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7C3AED))),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerAndSendVerificationEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF7C3AED),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Text(
                "Create Account",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: const Text("Sign In"),
        ),
      ],
    );
  }
}
