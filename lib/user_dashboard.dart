import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:serviceprovider/login_screen.dart';
import 'profile_screen.dart'; // ✅ Import ProfileScreen

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildDashboardCard({
    required Widget leading,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0B6B3E),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = 14;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EBFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "On Demand App",
          style: TextStyle(color: Colors.blue),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black54),
            onPressed: () {
              // TODO: open drawer or menu
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "User Home",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // ▼▼▼▼▼ "My Profile" card moved to the first position ▼▼▼▼▼
              _buildDashboardCard(
                leading: const Icon(Icons.person_outline, size: 48, color: Colors.black54),
                title: "My Profile",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              // ▲▲▲▲▲ "My Profile" card moved to the first position ▲▲▲▲▲

              // Search Services card
              _buildDashboardCard(
                leading: const Icon(Icons.search, size: 48, color: Colors.black54),
                title: "Search Services",
                onTap: () {
                  // TODO: navigate to Search Services screen
                },
              ),
              const SizedBox(height: 14),

              // View Services card
              _buildDashboardCard(
                leading: const Icon(Icons.grid_view_rounded, size: 48, color: Colors.black54),
                title: "View Services",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ViewServicesScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),

              // My Request card
              _buildDashboardCard(
                leading: const Icon(Icons.location_on, size: 48, color: Colors.black54),
                title: "My Request",
                onTap: () {
                  // TODO: navigate to My Request screen
                },
              ),
              const SizedBox(height: 14),

              // Payment History card
              _buildDashboardCard(
                leading: const Icon(Icons.history, size: 48, color: Colors.black54),
                title: "Payment History",
                onTap: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 6,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.home, color: Colors.blue),
                  SizedBox(height: 4),
                  Text("Home", style: TextStyle(color: Colors.blue)),
                ],
              ),
              InkWell(
                onTap: () => _logout(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.logout, color: Colors.grey),
                    SizedBox(height: 4),
                    Text("Logout", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// --- Placeholder Screens ---

// A placeholder screen for viewing available services.
class ViewServicesScreen extends StatelessWidget {
  const ViewServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Services'),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text(
          'A list of all available services will be shown here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

// A placeholder screen for viewing payment history.
class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text(
          'The user\'s transaction history will be displayed here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}