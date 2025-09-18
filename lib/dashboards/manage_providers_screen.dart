// lib/dashboards/manage_providers_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ManageProvidersScreen extends StatefulWidget {
  const ManageProvidersScreen({Key? key}) : super(key: key);

  @override
  _ManageProvidersScreenState createState() => _ManageProvidersScreenState();
}

class _ManageProvidersScreenState extends State<ManageProvidersScreen> {
  // Method to "soft delete" (reject) a provider
  Future<void> _deleteProvider(String userId, String username) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Action'),
          content: Text(
              'Are you sure you want to delete the provider "$username"? This will reject their profile and they will not be able to log in.'),
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
          'isApproved': false, // Ensure they are not marked as approved
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$username" has been deleted/rejected.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete provider: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Helper widget to build status chips for clarity
  Widget _buildStatusChip(bool isApproved, bool isRejected) {
    String label;
    Color color;
    if (isRejected) {
      label = 'Rejected';
      color = Colors.red;
    } else if (isApproved) {
      label = 'Approved';
      color = Colors.green;
    } else {
      label = 'Pending';
      color = Colors.orange;
    }
    return Chip(
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Service Providers'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Service Provider')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No service providers found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final providers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final providerDoc = providers[index];
              final providerData = providerDoc.data() as Map<String, dynamic>;
              final username = providerData['username'] ?? 'No Name';
              final email = providerData['email'] ?? 'No Email';
              final isApproved = providerData['isApproved'] ?? false;
              final isRejected = providerData['isRejected'] ?? false;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: FaIcon(FontAwesomeIcons.userTie),
                  ),
                  title: Text(username,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusChip(isApproved, isRejected),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.redAccent),
                        onPressed: () =>
                            _deleteProvider(providerDoc.id, username),
                        tooltip: 'Delete Provider',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}