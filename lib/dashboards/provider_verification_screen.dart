// lib/dashboards/provider_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'provider_detail_screen.dart'; // Ensure this new file is created

class ProviderVerificationScreen extends StatelessWidget {
  const ProviderVerificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Verifications'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Service Provider')
            .where('isProfileComplete', isEqualTo: true)
            .where('isApproved', isEqualTo: false)
            .where('isRejected', isEqualTo: false) // Only show non-rejected users
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error); // For debugging
            return const Center(
                child: Text('Something went wrong. Check security rules & indexes.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No pending verifications found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final providers = snapshot.data!.docs;
          return ListView.builder(
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final providerDoc = providers[index];
              final providerData = providerDoc.data() as Map<String, dynamic>;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        NetworkImage(providerData['profileImageUrl'] ?? ''),
                  ),
                  title: Text(providerData['username'] ?? 'No Name'),
                  subtitle: Text(providerData['email'] ?? 'No Email'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProviderDetailScreen(
                          providerDoc: providerDoc,
                        ),
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