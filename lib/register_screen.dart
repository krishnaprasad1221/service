import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  // State for the verification step
  bool _verificationEmailSent = false;
  Timer? _verificationTimer;
  bool _isResendingEmail = false;

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

  Future<void> _registerAndSendVerificationEmail() async {
    // Also check if a role is selected
    if (!_formKey.currentState!.validate() || _selectedRole == null) {
      // Manually trigger validation to show role error message if needed
      if (_selectedRole == null) setState(() {});
      Fluttertoast.showToast(msg: "Please fill all required fields.");
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

      // Start a timer to automatically check for verification
      _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _checkEmailVerificationAndCompleteProfile(isAutoCheck: true);
      });

      Fluttertoast.showToast(
        msg: "Verification email sent! Please check your inbox.",
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

      // Ensure loading is true before saving profile to prevent button clicks
      if (mounted) setState(() => _isLoading = true);

      try {
        final userId = user.uid;

        Map<String, dynamic> userData = {
          'username': _usernameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          'profileImageUrl': null, // Profile image can be added later
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

        await FirebaseAuth.instance.signOut(); // Force user to log in again

        Fluttertoast.showToast(
          msg: "Email verified! Registration complete. Please log in.",
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
        backgroundColor: Colors.green,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to resend email: $e",
        backgroundColor: Colors.red,
      );
    } finally {
      // Add a small delay to prevent spamming
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
            colors: [Colors.deepPurple, Colors.purple.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
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
            _buildHeader("Create Account", "Get started by filling out the form below"),
            const SizedBox(height: 24),
            _buildRoleSelector(),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _usernameController,
                label: "Full Name",
                icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? "Please enter your name" : null),
            const SizedBox(height: 16),
             _buildTextField(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _emailController,
                label: "Email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => !(v != null && v.contains('@')) ? "Enter a valid email" : null),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: _isPasswordVisible,
                onVisibilityToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                validator: (v) => (v != null && v.length < 6) ? "Password must be at least 6 characters" : null),
            const SizedBox(height: 16),
            _buildTextField(
                controller: _confirmPasswordController,
                label: "Confirm Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isPasswordVisible: _isConfirmPasswordVisible,
                onVisibilityToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                validator: (v) => v != _passwordController.text ? "Passwords do not match" : null),
            const SizedBox(height: 24),
            _buildRegisterButton(),
            const SizedBox(height: 24),
            _buildLoginLink(),
          ],
        ),
      ),
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
          Icon(Icons.mark_email_read_outlined, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          const Text("Check Your Email", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
            style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : () => _checkEmailVerificationAndCompleteProfile(),
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                : const Text("I Have Verified, Continue", style: TextStyle(fontSize: 16, color: Colors.white)),
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
                child: _isResendingEmail ? const Text("Sending...") : const Text("Resend Link"),
              ),
            ],
          ),
        ],
      ),
    );
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
        Text("I am a...", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: _roles.map((role) {
            final bool isSelected = _selectedRole == role;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedRole = role),
                child: Container(
                  margin: EdgeInsets.only(right: role == _roles.first ? 8.0 : 0.0, left: role == _roles.last ? 8.0 : 0.0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurple : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey[300]!),
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
        // Simple validation feedback
         if (_formKey.currentState?.validate() == false && _selectedRole == null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 12.0),
              child: Text("Please select a role", style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            )
      ],
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onVisibilityToggle,
    TextInputType? keyboardType,
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword && !isPasswordVisible,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
          ? IconButton(
              icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: onVisibilityToggle,
            )
          : null,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.deepPurple)),
      ),
    );
  }

  Widget _buildRegisterButton() {
     return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerAndSendVerificationEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
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


