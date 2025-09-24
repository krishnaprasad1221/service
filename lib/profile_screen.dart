<<<<<<< HEAD
// lib/profile_screen.dart

=======
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/login_screen.dart';
<<<<<<< HEAD
import 'user_edit_profile.dart'; 
=======
import 'edit_profile_screen.dart'; // Make sure this screen exists for users
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
<<<<<<< HEAD
=======
  // Using a Stream to listen for real-time profile updates.
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
  Stream<DocumentSnapshot>? _profileStream;

  @override
  void initState() {
    super.initState();
    _initializeProfileStream();
  }

<<<<<<< HEAD
=======
  /// Initializes the stream to listen for real-time changes to the user's profile.
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
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

<<<<<<< HEAD
  Future<void> _refreshProfile() async {
    _initializeProfileStream();
  }

=======
  /// Refreshes the profile data.
  Future<void> _refreshProfile() async {
    // This will re-trigger the StreamBuilder by re-assigning the stream
    _initializeProfileStream();
  }

  /// Securely signs the user out and navigates to the LoginScreen.
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

<<<<<<< HEAD
=======
  /// Shows a confirmation dialog to prevent accidental logouts.
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
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
<<<<<<< HEAD
          // ▼▼▼ ADDED: Fetch the address from the profile data ▼▼▼
          final String address = profile['address'] ?? 'No address provided';
=======
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
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
<<<<<<< HEAD
                    // ▼▼▼ ADDED: A new tile to display the user's address ▼▼▼
                    _InfoTile(
                        icon: Icons.location_on_outlined,
                        title: "Address",
                        value: address),
=======
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
                    const SizedBox(height: 30),
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

<<<<<<< HEAD
=======
  /// Builds the main action buttons for the profile screen.
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
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
<<<<<<< HEAD
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserEditProfileScreen()),
=======
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
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

<<<<<<< HEAD
// _ProfileHeader and _InfoTile widgets remain the same...

=======
/// A visually appealing header for the profile screen.
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
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

<<<<<<< HEAD
=======
/// A reusable widget for displaying profile information in a clean, card-based format.
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
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
<<<<<<< HEAD
}
=======
}
>>>>>>> 5319e7662288a608f5ad81322248d0b6044db7ac
