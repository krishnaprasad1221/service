// lib/customer_view_service_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/booking_confirmation_screen.dart'; // <-- IMPORT the new screen

class CustomerViewServiceScreen extends StatelessWidget {
  final String serviceId;

  const CustomerViewServiceScreen({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('services').doc(serviceId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.data!.exists) {
            return const Center(child: Text("Service not found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String serviceName = data['serviceName'] ?? 'Service';
          final String? imageUrl = data['serviceImageUrl'];
          final String description = data['description'] ?? 'No description available.';
          final String providerId = data['providerId'];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: Colors.deepPurple,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(serviceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 60, color: Colors.white54),
                        )
                      else
                        const Center(child: Icon(Icons.work, size: 60, color: Colors.white54)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildSectionTitle("Description"),
                  _buildDescriptionCard(description),
                  _buildSectionTitle("Provided By"),
                  _buildProviderInfoCard(providerId),
                  const SizedBox(height: 30),
                  _buildBookNowButton(
                    context: context,
                    serviceId: serviceId,
                    providerId: providerId,
                    serviceName: serviceName,
                  ),
                  const SizedBox(height: 30),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
      ),
    );
  }

  Widget _buildDescriptionCard(String description) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(description, style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5)),
      ),
    );
  }

  Widget _buildProviderInfoCard(String providerId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(providerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ListTile(title: Text("Provider information not available."));
        }
        final providerData = snapshot.data!.data() as Map<String, dynamic>;
        final providerName = providerData['username'] ?? 'Service Provider';
        final String? profilePicUrl = providerData['profileImageUrl'];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
              child: profilePicUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(providerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Verified Provider"),
          ),
        );
      },
    );
  }

  // ▼▼▼ THIS WIDGET IS NOW UPDATED ▼▼▼
  Widget _buildBookNowButton({
    required BuildContext context,
    required String serviceId,
    required String providerId,
    required String serviceName,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          // Navigate to the new screen, passing the required data
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingConfirmationScreen(
                serviceId: serviceId,
                providerId: providerId,
                serviceName: serviceName,
              ),
            ),
          );
        },
        child: const Text("Book This Service", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}