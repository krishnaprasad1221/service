// lib/view_services_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_view_service_screen.dart'; // <-- 1. IMPORT ADDED

class ViewServicesScreen extends StatelessWidget {
  const ViewServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('All Services'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('services').snapshots(),
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
                'No services available yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final services = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final serviceDoc = services[index];
              final serviceData = serviceDoc.data() as Map<String, dynamic>;

              // ▼▼▼ 2. WRAPPED WITH GESTUREDETECTOR AND ADDED ONTAP ▼▼▼
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Navigate to the new screen, passing the service's unique ID
                      builder: (_) => CustomerViewServiceScreen(serviceId: serviceDoc.id),
                    ),
                  );
                },
                child: ServiceCard(
                  serviceName: serviceData['serviceName'] ?? 'No Name',
                  category: serviceData['category'] ?? 'Uncategorized',
                  imageUrl: serviceData['serviceImageUrl'],
                  providerId: serviceData['providerId'],
                ),
              );
              // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
            },
          );
        },
      ),
    );
  }
}

// --- The ServiceCard and ProviderInfoChip widgets remain unchanged below ---

class ServiceCard extends StatelessWidget {
  final String serviceName;
  final String category;
  final String? imageUrl;
  final String providerId;

  const ServiceCard({
    super.key,
    required this.serviceName,
    required this.category,
    this.imageUrl,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: Colors.grey[200],
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        return progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image,
                            color: Colors.grey, size: 40);
                      },
                    )
                  : const Icon(Icons.work, color: Colors.grey, size: 40),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(), // Pushes the chip to the bottom
                  ProviderInfoChip(providerId: providerId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderInfoChip extends StatelessWidget {
  final String providerId;
  const ProviderInfoChip({super.key, required this.providerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(providerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('By: Unknown',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic));
        }

        final providerData = snapshot.data!.data() as Map<String, dynamic>;
        final providerName = providerData['username'] ?? 'Service Provider';

        return Chip(
          avatar: CircleAvatar(
            backgroundColor: Colors.deepPurple.shade100,
            child: Text(providerName.substring(0, 1)),
          ),
          label: Text(
            providerName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}