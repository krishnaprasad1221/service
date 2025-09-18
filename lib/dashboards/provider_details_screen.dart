// lib/dashboards/provider_details_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ProviderDetailsScreen extends StatelessWidget {
  final String userId;
  const ProviderDetailsScreen({Key? key, required this.userId}) : super(key: key);

  Future<void> _deleteProvider(BuildContext context, String username) async {
    // Confirmation and deletion logic is the same as on the list screen
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete "$username"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isRejected': true,
          'isApproved': false,
        });
        // Pop the screen after deletion
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$username" has been deleted.'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete provider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Details"),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Could not load provider details."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String username = data['username'] ?? 'N/A';
          final String? documentUrl = data['documentUrl'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: data['profileImageUrl'] != null ? NetworkImage(data['profileImageUrl']) : null,
                  child: data['profileImageUrl'] == null ? const Icon(Icons.person, size: 50) : null,
                ),
                const SizedBox(height: 16),
                Text(username, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                _InfoTile(icon: Icons.email, title: "Email", value: data['email'] ?? 'N/A'),
                _InfoTile(icon: Icons.phone, title: "Phone", value: data['phone'] ?? 'N/A'),
                _InfoTile(icon: Icons.location_city, title: "Address", value: data['address'] ?? 'N/A'),
                _InfoTile(icon: Icons.work, title: "Service Field", value: data['serviceField'] ?? 'N/A'),
                const Divider(height: 32),
                if (documentUrl != null && documentUrl.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text("View Verification Document"),
                    onPressed: () async {
                      final Uri url = Uri.parse(documentUrl);
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open document.')));
                      }
                    },
                  ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Delete This Provider"),
                  onPressed: () => _deleteProvider(context, username),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Helper widget for displaying info in the details screen
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title, style: const TextStyle(color: Colors.grey)),
        subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black)),
      ),
    );
  }
}