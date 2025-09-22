// lib/dashboards/serviceprovider_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/login_screen.dart';
import '../create_service_screen.dart';
import '../manage_services_screen.dart';
import '../service_provider_profile_screen.dart';

class ServiceProviderDashboard extends StatefulWidget {
  const ServiceProviderDashboard({super.key});

  @override
  State<ServiceProviderDashboard> createState() => _ServiceProviderDashboardState();
}

class _ServiceProviderDashboardState extends State<ServiceProviderDashboard> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isApproved = false;
  String _username = 'Service Provider';
  String? _profileImageUrl;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
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
            _profileImageUrl = data['profileImageUrl'];
            _isLoading = false;
            _pages = [
              _DashboardHomeTab(username: _username, profileImageUrl: _profileImageUrl),
              const _ManageBookingsTab(),
              const ServiceProviderProfileScreen(),
            ];
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error checking approval status: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isApproved ? _buildApprovedDashboard() : _buildPendingScreen();
  }

  Widget _buildApprovedDashboard() {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildPendingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 80, color: Colors.orangeAccent),
                const SizedBox(height: 24),
                const Text("Approval Pending", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  "Welcome, $_username! Your account is under review by the admin. We'll notify you upon approval.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- DASHBOARD HOME TAB WIDGET ---
class _DashboardHomeTab extends StatelessWidget {
  final String username;
  final String? profileImageUrl;

  const _DashboardHomeTab({required this.username, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            _buildCurvedHeader(context),
            _buildSectionTitle("At a Glance"),
            _buildKpiGrid(),
            _buildActionRequiredCard(context),
            _buildSectionTitle("Manage Business"),
            _buildQuickActionsGrid(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurvedHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: ClipPath(
        clipper: _AppBarClipper(),
        child: Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Subtle background pattern
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: Image.asset('assets/header_pattern.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox()), // Add a pattern image to your assets
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Welcome back,", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18)),
                          Text(
                            username,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                      child: profileImageUrl == null ? const Icon(Icons.person, size: 35, color: Colors.white) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
        child: Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
        ),
      ),
    );
  }
  
  Widget _buildKpiGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
        children: [
          _InfoCard(title: 'Completed Jobs', value: '156', icon: Icons.check_circle, color: Colors.green),
          _InfoCard(title: 'Your Rating', value: '4.8 ★', icon: Icons.star, color: Colors.amber),
        ],
      ),
    );
  }

  Widget _buildActionRequiredCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
             gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.orange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: ListTile(
            leading: const Icon(Icons.notifications_active, color: Colors.white, size: 30),
            title: const Text("3 New Requests", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
            subtitle: Text("Respond now to improve your rating", style: TextStyle(color: Colors.white.withOpacity(0.9))),
            trailing: const Icon(Icons.arrow_forward, color: Colors.white),
            onTap: () {
                // This should ideally set the bottom nav index to 1
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Navigating to bookings...")));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: [
          _ActionCard(
            title: "Add New Service",
            icon: Icons.add_circle,
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateServiceScreen())),
          ),
          _ActionCard(
            title: "Manage My Services",
            icon: Icons.edit_note,
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageServicesScreen())),
          ),
        ],
      ),
    );
  }
}

// --- BOOKINGS TAB WIDGET (Placeholder) ---
class _ManageBookingsTab extends StatelessWidget {
  const _ManageBookingsTab();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Bookings'), backgroundColor: Colors.deepPurple),
      body: const Center(child: Text('A list of new, active, and completed bookings will appear here.')),
    );
  }
}

// --- REUSABLE UI WIDGETS ---
class _InfoCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _InfoCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(width: 12),
          // ▼▼▼▼▼ WRAPPED IN EXPANDED TO PREVENT OVERFLOW ▼▼▼▼▼
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ▲▲▲▲▲ INFO CARD IS NOW MORE ROBUST AND WILL NOT OVERFLOW ▲▲▲▲▲

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 30, color: color)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS FOR CHART PLACEHOLDER ---
class _Bar extends StatelessWidget {
  final double height;
  final String label;
  const _Bar({required this.height, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

// --- CUSTOM CLIPPER FOR THE CURVED APP BAR ---
class _AppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50); // Start the curve 50px from the bottom
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}