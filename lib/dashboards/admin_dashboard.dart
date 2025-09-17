// lib/dashboards/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/dashboards/provider_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:serviceprovider/login_screen.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Hardcoded KPI values for demonstration
  final String totalRevenue = "₹ 85,250";
  final int totalUsers = 1250;
  final int totalProviders = 180;
  final int liveBookings = 15;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF0D47A1),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Action Required",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Live stream of pending providers
            _buildVerificationCard(context),
            const SizedBox(height: 24),
            const Text(
              "Platform Overview",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _KpiCard(title: 'Total Revenue', value: totalRevenue, icon: FontAwesomeIcons.indianRupeeSign, color: Colors.green),
                _KpiCard(title: 'Total Users', value: totalUsers.toString(), icon: FontAwesomeIcons.users, color: Colors.blue),
                _KpiCard(title: 'Service Providers', value: totalProviders.toString(), icon: FontAwesomeIcons.userTie, color: Colors.orange),
                _KpiCard(title: 'Live Bookings', value: liveBookings.toString(), icon: FontAwesomeIcons.solidCalendarCheck, color: Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Card that shows the count of pending verifications
  Widget _buildVerificationCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Service Provider')
          .where('isProfileComplete', isEqualTo: true)
          .where('isApproved', isEqualTo: false)
          .where('isRejected', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final count = snapshot.data?.docs.length ?? 0;
        return ActionCard(
          title: 'Verify Providers',
          icon: FontAwesomeIcons.userCheck,
          count: count,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProviderVerificationScreen()),
            );
          },
        );
      },
    );
  }
}

// Reusable widget for the action card
class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const ActionCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.count,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: ListTile(
        onTap: onTap,
        leading: FaIcon(icon, color: Colors.orange, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$count providers waiting for approval'),
        trailing: (count > 0)
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
    );
  }
}

// Reusable widget for the KPI cards
class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(title, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}