import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:serviceprovider/create_service_screen.dart';
import 'package:serviceprovider/edit_service_screen.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({Key? key}) : super(key: key);

  @override
  _ManageServicesScreenState createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  /// Shows a confirmation dialog and deletes a service document and its associated image from storage.
  Future<void> _deleteService(DocumentSnapshot serviceDoc) async {
    final serviceData = serviceDoc.data() as Map<String, dynamic>;
    final serviceName = serviceData['serviceName'] ?? 'the service';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Deletion'),
        content: Text(
            'Are you sure you want to delete "$serviceName"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show a loading indicator while deleting
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleting "$serviceName"...'),
    ));

    try {
      // Delete the image from Firebase Storage if it exists
      if (serviceData['serviceImageUrl'] != null) {
        final imageUrl = serviceData['serviceImageUrl'] as String;
        if (imageUrl.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(imageUrl).delete();
        }
      }
      // Delete the document from Firestore
      await serviceDoc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$serviceName" was successfully deleted.'),
          backgroundColor: Colors.green,
        ));
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting service: ${e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage My Services')),
        body: const Center(
            child: Text('You must be logged in to manage services.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage My Services'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purple.shade300],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('providerId', isEqualTo: _currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final serviceDoc = snapshot.data!.docs[index];
              return _ServiceCard(
                serviceDoc: serviceDoc,
                onDelete: () => _deleteService(serviceDoc),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreateServiceScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text("Add Service"),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  /// A visually engaging widget to show when the user has no services.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_business_outlined,
              size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text('No Services Found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Tap the "Add Service" button to create your first one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

/// A custom card widget to display service information in a more visually appealing way.
class _ServiceCard extends StatelessWidget {
  final DocumentSnapshot serviceDoc;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.serviceDoc,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = serviceDoc.data() as Map<String, dynamic>;
    final imageUrl = data['serviceImageUrl'] as String?;
    final serviceName = data['serviceName'] ?? 'No Name';
    final category = data['category'] ?? 'N/A';
    final price = data['price'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? Image.network(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    // Loading and error builders for better UX
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                                height: 150,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                      height: 150,
                      child: Icon(Icons.broken_image,
                          size: 50, color: Colors.grey),
                    ),
                  )
                : Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(
                        child: Icon(Icons.image, size: 50, color: Colors.grey)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Name and Category Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Chip(
                      label: Text(category),
                      backgroundColor: Colors.deepPurple.withOpacity(0.1),
                      labelStyle: const TextStyle(color: Colors.deepPurple),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Price
                Text(
                  '₹${price.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700]),
                ),
                const Divider(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      onPressed: onDelete,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditServiceScreen(serviceId: serviceDoc.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
