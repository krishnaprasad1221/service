// lib/service_provider_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/service_provider_edit_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceProviderProfileScreen extends StatefulWidget {
  const ServiceProviderProfileScreen({super.key});

  @override
  State<ServiceProviderProfileScreen> createState() =>
      _ServiceProviderProfileScreenState();
}

class _ServiceProviderProfileScreenState
    extends State<ServiceProviderProfileScreen> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfileDoc();
  }

  Future<Map<String, dynamic>?> _fetchProfileDoc() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.exists ? doc.data() : {};
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _fetchProfileDoc();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Could not load profile."));
          }

          final profile = snapshot.data!;
          final String username = profile['username']?.toString() ?? 'Guest';
          final String phone = profile['phone']?.toString() ?? 'Not Provided';
          final String email = profile['email']?.toString() ?? 'Not Provided';
          
          final String address = profile['address']?.toString() ?? 'Not Provided';
          final String serviceField = profile['serviceField']?.toString() ?? 'Not Provided';
          final String? documentUrl = profile['documentUrl'];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(username,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.indigo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                         backgroundImage: profile['profileImageUrl'] != null
                            ? NetworkImage(profile['profileImageUrl'])
                            : null,
                        child: profile['profileImageUrl'] == null
                            ? Icon(Icons.person, size: 60, color: Colors.indigo)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _infoCard(Icons.email, "Email", email, Colors.orange),
                      const SizedBox(height: 12),
                      _infoCard(Icons.phone, "Phone", phone, Colors.green),
                      const SizedBox(height: 12),
                      _infoCard(Icons.location_on, "Address", address, Colors.purple),
                      const SizedBox(height: 12),
                      _infoCard(Icons.work, "Service Field", serviceField, Colors.brown),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Verification Document",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              if (documentUrl != null && documentUrl.isNotEmpty)
                                Center(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.link),
                                    label: const Text("View Document"),
                                    onPressed: () async {
                                      final Uri url = Uri.parse(documentUrl);
                                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                         ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not open document link.')),
                                        );
                                      }
                                    },
                                  ),
                                )
                              else
                                const Text("No document has been submitted.", style: TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text("Edit Profile"),
                            onPressed: () async {
                              final updated = await Navigator.push<bool?>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ServiceProviderEditProfileScreen()),
                              );
                              if (updated == true) {
                                await _refresh();
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Back"),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}