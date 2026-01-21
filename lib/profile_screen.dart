// lib/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/login_screen.dart';
import 'user_edit_profile.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Stream<DocumentSnapshot>? _profileStream;

  @override
  void initState() {
    super.initState();
    _initializeProfileStream();
  }

  void _initializeProfileStream() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _profileStream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots();
      });
    }
  }

  Future<void> _refreshProfile() async {
    _initializeProfileStream();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildProfileExtrasSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "About your ServeSphere account",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: Colors.deepPurple.withOpacity(0.08),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.deepPurple),
              title: const Text(
                'About ServeSphere',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'ServeSphere helps you discover trusted nearby service providers for home and appliance needs in one place.',
              ),
              onTap: () => _showAboutDialog(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: Colors.deepPurple.withOpacity(0.08),
            child: ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.deepPurple),
              title: const Text(
                'Help & Support',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Need help with your account or a booking? View basic help info and contact options.',
              ),
              onTap: () => _showHelpDialog(context),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: Colors.deepPurple.withOpacity(0.08),
            child: const ListTile(
              leading: Icon(Icons.verified_user_outlined, color: Colors.deepPurple),
              title: Text(
                'Account & Data',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Your profile details are used only to help providers reach you and personalize your experience.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('About ServeSphere'),
          content: const Text(
            'ServeSphere is your on-demand nearby service partner. Discover verified providers, track your requests, and use SelfFix guidance to solve simple issues on your own.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Help & Support'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• For urgent booking issues, contact your provider using the phone number shown in your booking details.'),
              SizedBox(height: 8),
              Text('• For account or profile issues, you can log out and log back in, or update your profile details from this screen.'),
              SizedBox(height: 8),
              Text('• You can also use the SelfFix assistant on the home screen to troubleshoot common appliance problems before booking.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text("Something went wrong. Please try again."));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Could not load profile."));
          }

          final profile = snapshot.data!.data() as Map<String, dynamic>;
          final String username = profile['username'] ?? 'Guest User';
          final String phone = profile['phone'] ?? 'Not Provided';
          final String email = profile['email'] ?? 'Not Provided';
          // ▼▼▼ ADDED: Fetch the address from the profile data ▼▼▼
          final String address = profile['address'] ?? 'No address provided';
          final String? profileImageUrl = profile['profileImageUrl'];

          return RefreshIndicator(
            onRefresh: _refreshProfile,
            child: CustomScrollView(
              slivers: [
                _ProfileHeader(
                    username: username, profileImageUrl: profileImageUrl),
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _InfoTile(
                        icon: Icons.email_outlined,
                        title: "Email Address",
                        value: email),
                    _InfoTile(
                        icon: Icons.phone_outlined,
                        title: "Phone Number",
                        value: phone),
                    // ▼▼▼ ADDED: A new tile to display the user's address ▼▼▼
                    _InfoTile(
                        icon: Icons.location_on_outlined,
                        title: "Address",
                        value: address),
                    const SizedBox(height: 24),
                    _buildProfileExtrasSection(context),
                    const SizedBox(height: 24),
                    _buildActionButtons(context),
                    const SizedBox(height: 40),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text("Edit Profile"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserEditProfileScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout_outlined),
            label: const Text("Logout"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showLogoutConfirmationDialog,
          ),
        ],
      ),
    );
  }
}

// _ProfileHeader and _InfoTile widgets remain the same...

class _ProfileHeader extends StatelessWidget {
  final String username;
  final String? profileImageUrl;

  const _ProfileHeader({required this.username, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          username,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (profileImageUrl != null)
              Image.network(
                profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.person, size: 90, color: Colors.white54),
              )
            else
              const Center(
                  child: Icon(Icons.person, size: 90, color: Colors.white54)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.black.withOpacity(0.7)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoTile(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      shadowColor: Colors.deepPurple.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title:
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ),
    );
  }
}