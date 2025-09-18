// lib/dashboards/manage_approved_providers_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:serviceprovider/dashboards/provider_details_screen.dart';
import 'package:serviceprovider/dashboards/manage_approved_providers_screen.dart';

class ManageApprovedProvidersScreen extends StatefulWidget {
  const ManageApprovedProvidersScreen({Key? key}) : super(key: key);

  @override
  _ManageApprovedProvidersScreenState createState() =>
      _ManageApprovedProvidersScreenState();
}

class _ManageApprovedProvidersScreenState
    extends State<ManageApprovedProvidersScreen> {
  Future<void> _deleteProvider(String userId, String username) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete "$username"? Their profile will be marked as rejected and they will no longer be able to log in.'),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$username" has been deleted.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Providers'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Service Provider')
            .where('isApproved', isEqualTo: true) // <-- Filters for approved only
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No approved service providers found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final providers = snapshot.data!.docs;

          return ListView.builder(
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final providerDoc = providers[index];
              final providerData = providerDoc.data() as Map<String, dynamic>;
              final username = providerData['username'] ?? 'No Name';
              final serviceField = providerData['serviceField'] ?? 'No Service Field';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundImage: providerData['profileImageUrl'] != null
                          ? NetworkImage(providerData['profileImageUrl'])
                          : null,
                      child: providerData['profileImageUrl'] == null
                          ? const FaIcon(FontAwesomeIcons.userTie)
                          : null),
                  title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(serviceField),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteProvider(providerDoc.id, username),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderDetailsScreen(userId: providerDoc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}