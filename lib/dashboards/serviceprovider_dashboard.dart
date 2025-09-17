// lib/dashboards/serviceprovider_dashboard.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- Import Firestore
import 'package:serviceprovider/login_screen.dart';
import '../create_service_screen.dart';
import '../manage_services_screen.dart';
import '../service_provider_profile_screen.dart';

// ▼▼▼▼▼ CONVERTED TO STATEFULWIDGET ▼▼▼▼▼
class ServiceProviderDashboard extends StatefulWidget {
  const ServiceProviderDashboard({super.key});

  @override
  State<ServiceProviderDashboard> createState() =>
      _ServiceProviderDashboardState();
}

class _ServiceProviderDashboardState extends State<ServiceProviderDashboard> {
  int _selectedIndex = 0;

  // ▼▼▼▼▼ NEW STATE VARIABLES ▼▼▼▼▼
  bool _isLoading = true;
  bool _isApproved = false;
  String _username = 'Service Provider';
  // ▲▲▲▲▲ NEW STATE VARIABLES ▲▲▲▲▲


  final List<Map<String, dynamic>> _menuItems = [
    { "title": "Create Services", "icon": FontAwesomeIcons.plusCircle, "color": Colors.blue, },
    { "title": "Update Services", "icon": FontAwesomeIcons.penToSquare, "color": Colors.orange, },
    { "title": "Service Request", "icon": FontAwesomeIcons.solidBell, "color": Colors.purple, },
    { "title": "View Feedback", "icon": FontAwesomeIcons.solidCommentDots, "color": Colors.green, },
    { "title": "My Profile", "icon": FontAwesomeIcons.userCircle, "color": Colors.teal, },
  ];

  // ▼▼▼▼▼ NEW: FETCH USER STATUS ON SCREEN LOAD ▼▼▼▼▼
  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If no user, stop loading and maybe log out
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _isApproved = data['isApproved'] ?? false;
            _username = data['username'] ?? 'Service Provider';
            _isLoading = false;
          });
        }
      } else {
        // Document doesn't exist, treat as not approved
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      // Handle potential errors
      print("Error checking approval status: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // ▲▲▲▲▲ NEW: FETCH USER STATUS ON SCREEN LOAD ▲▲▲▲▲

  void _onItemTapped(int index) async {
    // ... (Your existing _onItemTapped method remains the same)
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) { // Logout is the second item (index 1)
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // ▼▼▼▼▼ NEW WIDGET FOR PENDING SCREEN ▼▼▼▼▼
  Widget _buildPendingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 24),
            const Text(
              "Approval Pending",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Welcome, $_username! Your account is under review. You will be notified once the admin approves your request. Please check back later.",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  // ▲▲▲▲▲ NEW WIDGET FOR PENDING SCREEN ▲▲▲▲▲

  // ▼▼▼▼▼ NEW WIDGET FOR MAIN DASHBOARD CONTENT ▼▼▼▼▼
  Widget _buildDashboardGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3F9FF), Color(0xFFE3EEFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          final color = (item['color'] as Color);
          final icon = item['icon'] as IconData;
          final title = (item['title'] ?? '').toString();

          return GestureDetector(
            onTap: () {
              if (title == "Create Services") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateServiceScreen()),
                );
                return;
              }

              if (title == "Update Services") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageServicesScreen()),
                );
                return;
              }

              if (title == "My Profile") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServiceProviderProfileScreen(),
                  ),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title tapped (TODO)')),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(icon, size: 30, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  // ▲▲▲▲▲ NEW WIDGET FOR MAIN DASHBOARD CONTENT ▲▲▲▲▲

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Dashboard"), // Changed title for clarity
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      // ▼▼▼▼▼ CONDITIONAL BODY BASED ON STATUS ▼▼▼▼▼
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isApproved
              ? _buildDashboardGrid()
              : _buildPendingScreen(),
      // ▲▲▲▲▲ CONDITIONAL BODY BASED ON STATUS ▲▲▲▲▲
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: "Logout",
          ),
        ],
      ),
    );
  }
}