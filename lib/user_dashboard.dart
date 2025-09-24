// lib/user_dashboard.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/login_screen.dart';
import 'package:serviceprovider/profile_screen.dart';
import 'package:serviceprovider/view_services_screen.dart';
import 'package:serviceprovider/my_requests_screen.dart';
import 'package:serviceprovider/payment_history_screen.dart';
import 'package:serviceprovider/service_search_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  String _username = 'User';
  // NEW: State variable to hold the profile image URL
  String? _profileImageUrl;
  bool _isLoading = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // MODIFIED: This function now also fetches the profileImageUrl
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _username = doc.data()!['username'] ?? 'User';
          // NEW: Get the profile image URL from the document data
          _profileImageUrl = doc.data()!['profileImageUrl'];
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    } finally {
      _pages = [
        _buildHomeContent(),
        const MyRequestsScreen(),
        const ProfileScreen(),
      ];
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'My Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        _buildHeader(),
        _buildSectionTitle("Categories"),
        _buildCategoryList(),
        _buildSectionTitle("Quick Actions"),
        _buildDashboardGrid(),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  // MODIFIED: This widget now displays the profile photo
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 220.0,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      elevation: 2,
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16.0,
                right: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NEW: Row to hold the text and the profile photo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, $_username!",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Find the best services near you",
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // NEW: CircleAvatar to display the profile photo
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? const Icon(Icons.person,
                              size: 30, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSearchBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ServiceSearchScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: const [
            Icon(Icons.search, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "Search for a service...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800]),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    final categories = [
      {'icon': Icons.cleaning_services, 'label': 'Cleaning', 'color': Colors.lightBlue},
      {'icon': Icons.plumbing, 'label': 'Plumbing', 'color': Colors.orange},
      {'icon': Icons.brush, 'label': 'Painting', 'color': Colors.pink},
      {'icon': Icons.electrical_services, 'label': 'Electrician', 'color': Colors.amber},
      {'icon': Icons.handyman, 'label': 'Repairs', 'color': Colors.brown},
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _buildCategoryChip(
              category['label'] as String,
              category['icon'] as IconData,
              category['color'] as Color,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildListDelegate([
          _buildDashboardCard(
            title: "View All\nServices",
            icon: Icons.apps_rounded,
            color: Colors.blue,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ViewServicesScreen())),
          ),
          _buildDashboardCard(
            title: "Payment\nHistory",
            icon: Icons.history_rounded,
            color: Colors.green,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
          ),
        ]),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
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
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}