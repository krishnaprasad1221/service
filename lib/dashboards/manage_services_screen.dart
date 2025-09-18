// lib/dashboards/manage_services_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({Key? key}) : super(key: key);

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  // ▼▼▼▼▼ THIS FUNCTION IS UPDATED TO BE MORE ROBUST ▼▼▼▼▼
  Future<void> _deleteService(DocumentSnapshot serviceDoc) async {
    final serviceData = serviceDoc.data() as Map<String, dynamic>;
    final serviceName = serviceData['serviceName'] ?? 'Unknown Service';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete the service "$serviceName"? This action cannot be undone.'),
        actions: [
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
      ),
    );

    if (confirm != true) return; // Exit if user cancels

    try {
      // Step 1: Attempt to delete the image from Firebase Storage.
      // We will wrap this in its own try-catch block so that if it fails,
      // we can still proceed to delete the database entry.
      if (serviceData['serviceImageUrl'] != null) {
        final imageUrl = serviceData['serviceImageUrl'] as String;
        if (imageUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(imageUrl).delete();
          } on FirebaseException catch (e) {
            // If the object doesn't exist, we can safely ignore the error because
            // our goal was to have it deleted anyway.
            if (e.code == 'object-not-found') {
              print('Image not found in Storage, proceeding to delete Firestore doc.');
            } else {
              // For any other storage errors, we can log them but won't stop the process.
              print('Could not delete image from storage: ${e.message}');
            }
          }
        }
      }

      // Step 2: Always proceed to delete the document from Firestore.
      await serviceDoc.reference.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$serviceName" was deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // This will now primarily catch errors from the Firestore deletion.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting service document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // ▲▲▲▲▲ THIS FUNCTION IS UPDATED TO BE MORE ROBUST ▲▲▲▲▲

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage All Services'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('services').orderBy('createdAt', descending: true).snapshots(),
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
                'No services found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final services = snapshot.data!.docs;

          return ListView.builder(
            itemCount: services.length,
            itemBuilder: (context, index) {
              final serviceDoc = services[index];
              final data = serviceDoc.data() as Map<String, dynamic>;

              final imageUrl = data['serviceImageUrl'] ?? '';
              final serviceName = data['serviceName'] ?? 'No Name';
              final providerName = data['providerName'] ?? 'N/A';
              final price = data['price'] ?? 0.0;
              final pricingType = data['pricingType'] ?? 'Fixed';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              height: 150,
                              child: Center(
                                child: Icon(Icons.broken_image, color: Colors.grey, size: 40)
                              )
                            ),
                      ),
                    ListTile(
                      title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('By: $providerName\nPrice: ₹$price ${pricingType == 'Per Hour' ? '/hr' : ''}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        onPressed: () => _deleteService(serviceDoc),
                        tooltip: 'Delete Service',
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}