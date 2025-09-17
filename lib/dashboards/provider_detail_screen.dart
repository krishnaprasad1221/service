// lib/dashboards/provider_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ProviderDetailScreen extends StatelessWidget {
  final DocumentSnapshot providerDoc;

  const ProviderDetailScreen({Key? key, required this.providerDoc})
      : super(key: key);

  // Handles updating the provider's status in Firestore
  Future<void> _handleApproval(BuildContext context, bool isApproved) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(providerDoc.id)
          .update({
        'isApproved': isApproved,
        'isRejected': !isApproved, // Set isRejected to the opposite of isApproved
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Provider has been ${isApproved ? 'Approved' : 'Rejected'}."),
        backgroundColor: isApproved ? Colors.green : Colors.red,
      ));
      Navigator.pop(context); // Go back to the list screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to update status: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = providerDoc.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(data['username'] ?? 'Provider Details'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', data['email']),
            _buildDetailRow('Phone', data['phone']),
            _buildDetailRow('Address', data['address']),
            _buildDetailRow('Field of Service', data['serviceField']),
            const SizedBox(height: 20),
            if (data['documentUrl'] != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description),
                  label: const Text('View Legal Document'),
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(data['documentUrl']))) {
                      await launchUrl(Uri.parse(data['documentUrl']));
                    }
                  },
                ),
              ),
            const SizedBox(height: 40),
            // Accept and Reject buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Accept'),
                    onPressed: () => _handleApproval(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text('Reject'),
                    onPressed: () => _handleApproval(context, false),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Reusable widget for displaying details
  Widget _buildDetailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value ?? 'Not Provided', style: const TextStyle(fontSize: 16)),
          const Divider(height: 16),
        ],
      ),
    );
  }
}