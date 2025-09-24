import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  /// Helper widget to display a colored status chip based on the booking status.
  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String text = status[0].toUpperCase() + status.substring(1); // Capitalize

    switch (status) {
      case 'accepted':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.check_circle;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.hourglass_top_outlined;
        break;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: const Center(child: Text('Please log in to see your requests.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .where('customerId', isEqualTo: user.uid)
            .orderBy('bookingTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(context);
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'You have not made any service requests yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final scheduledDate =
                  (data['scheduledDateTime'] as Timestamp).toDate();
              final formattedDate =
                  DateFormat.yMMMd().add_jm().format(scheduledDate);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(data['serviceName'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Scheduled for: $formattedDate'),
                  trailing: _buildStatusChip(data['status']),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This usually means a database index is missing. Please check your debug console for a link to create it.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
