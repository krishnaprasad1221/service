// lib/service_search_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- FIX: Corrected this import statement
import 'package:serviceprovider/customer_view_service_screen.dart';

class ServiceSearchScreen extends StatefulWidget {
  const ServiceSearchScreen({super.key});

  @override
  State<ServiceSearchScreen> createState() => _ServiceSearchScreenState();
}

class _ServiceSearchScreenState extends State<ServiceSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<QuerySnapshot>? _searchResultsFuture;

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResultsFuture = null;
      });
      return;
    }

    final searchQuery = FirebaseFirestore.instance
        .collection('services')
        .where('serviceName', isGreaterThanOrEqualTo: query)
        .where('serviceName', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    setState(() {
      _searchResultsFuture = searchQuery;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search services...",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
      ),
      body: _searchResultsFuture == null
          ? _buildInitialView()
          : _buildSearchResults(),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Search for any service',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<QuerySnapshot>(
      future: _searchResultsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading results."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No services found."));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final serviceDoc = snapshot.data!.docs[index];
            final data = serviceDoc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: data['serviceImageUrl'] != null
                      ? NetworkImage(data['serviceImageUrl'])
                      : null,
                  child: data['serviceImageUrl'] == null ? const Icon(Icons.work) : null,
                ),
                title: Text(data['serviceName'] ?? 'No Name'),
                subtitle: Text(data['category'] ?? 'Uncategorized'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerViewServiceScreen(serviceId: serviceDoc.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}