import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/login_screen.dart';
import 'package:serviceprovider/service_provider_edit_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceProviderProfileScreen extends StatefulWidget {
  const ServiceProviderProfileScreen({super.key});

  @override
  State<ServiceProviderProfileScreen> createState() =>
      _ServiceProviderProfileScreenState();
}

class _ServiceProviderProfileScreenState
    extends State<ServiceProviderProfileScreen> {
  late Future<DocumentSnapshot> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfileDoc();
  }

  /// Fetches the user document from Firestore.
  Future<DocumentSnapshot> _fetchProfileDoc() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // This case should ideally not be reached if AuthWrapper is working correctly.
      throw Exception("No user is currently logged in.");
    }
    return FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  }

  /// Refreshes the profile data, typically after an edit.
  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _fetchProfileDoc();
    });
  }

  /// Securely signs the user out and navigates to the LoginScreen.
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Shows a confirmation dialog to prevent accidental logouts.
  Future<void> _showLogoutConfirmationDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _logout();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<DocumentSnapshot>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.data!.exists) {
            return const Center(child: Text("Could not load profile."));
          }

          // Safely extract data from the snapshot
          final profile = snapshot.data!.data() as Map<String, dynamic>;
          final String username = profile['username'] ?? 'Guest';
          final String phone = profile['phone'] ?? 'Not Provided';
          final String email = profile['email'] ?? 'Not Provided';
          final String address = profile['address'] ?? 'Not Provided';
          final String serviceField = profile['serviceField'] ?? 'Not Provided';
          final String? documentUrl = profile['documentUrl'];
          final String? profileImageUrl = profile['profileImageUrl'];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.deepPurple,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Profile image with a fallback icon
                      if (profileImageUrl != null)
                        Image.network(
                          profileImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.person, size: 90, color: Colors.white54),
                        )
                      else
                         const Center(child: Icon(Icons.person, size: 90, color: Colors.white54)),
                      // Gradient overlay for better text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  _InfoTile(icon: Icons.email, title: "Email Address", value: email),
                  _InfoTile(icon: Icons.phone, title: "Phone Number", value: phone),
                  _InfoTile(icon: Icons.location_on, title: "Address", value: address),
                  _InfoTile(icon: Icons.work, title: "Service Field", value: serviceField),
                  _DocumentTile(documentUrl: documentUrl),
                  const SizedBox(height: 30),
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the main action buttons for the profile screen.
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text("Edit Profile"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              // Navigate to the edit screen and wait for a result.
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ServiceProviderEditProfileScreen()),
              );
              // If the edit screen returns 'true', it means the profile was updated.
              if (result == true) {
                _refreshProfile();
              }
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showLogoutConfirmationDialog,
          ),
        ],
      ),
    );
  }
}

/// A reusable widget for displaying profile information in a clean, card-based format.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}

/// A special tile for handling the verification document link.
class _DocumentTile extends StatelessWidget {
  final String? documentUrl;
  const _DocumentTile({this.documentUrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        leading: const Icon(Icons.description, color: Colors.deepPurple),
        title: Text("Verification Document", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        trailing: (documentUrl != null && documentUrl!.isNotEmpty)
            ? OutlinedButton(
                child: const Text("View"),
                onPressed: () async {
                  final uri = Uri.parse(documentUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open document link.')),
                    );
                  }
                },
              )
            : null,
        subtitle: (documentUrl == null || documentUrl!.isEmpty)
            ? const Text("Not Submitted", style: TextStyle(fontStyle: FontStyle.italic))
            : null,
      ),
    );
  }
}

