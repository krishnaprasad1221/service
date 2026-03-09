// lib/view_services_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_view_service_screen.dart'; // <-- 1. IMPORT ADDED

class _CatalogService {
  final String name;
  final String category;
  final String? serviceType;
  final String? location;
  final double rating;
  final int ratingCount;

  const _CatalogService({
    required this.name,
    required this.category,
    this.serviceType,
    this.location,
    this.rating = 4.5,
    this.ratingCount = 0,
  });
}

class _SeedService {
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final String? serviceType;

  const _SeedService({
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    this.serviceType,
  });
}

const List<_SeedService> _demoSeedServices = <_SeedService>[
  _SeedService(
    name: 'AC Mechanic',
    category: 'Appliance',
    description: 'AC servicing, gas refill, and cooling issues.',
    imageUrl:
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Fridge Repair',
    category: 'Appliance',
    description: 'Cooling issues, noise, and compressor checks.',
    imageUrl:
        'https://images.unsplash.com/photo-1527515637462-cff94eecc1ac?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'TV Repair',
    category: 'Electronics',
    description: 'Screen, sound, and connectivity problems.',
    imageUrl:
        'https://images.unsplash.com/photo-1521747116042-5a810fda9664?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Car Wash Spa',
    category: 'Car Care',
    description: 'Exterior wash, interior vacuum, and polish.',
    imageUrl:
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'House Cleaning',
    category: 'Cleaning',
    description: 'Full home deep cleaning service.',
    imageUrl:
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Bathroom Cleaning',
    category: 'Cleaning',
    description: 'Tiles, fittings, and floor cleaning.',
    imageUrl:
        'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Kitchen Cleaning',
    category: 'Cleaning',
    description: 'Degreasing, chimney, and surfaces.',
    imageUrl:
        'https://images.unsplash.com/photo-1501045661006-fcebe0257c3f?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Sofa Cleaning',
    category: 'Cleaning',
    description: 'Stain removal and fabric care.',
    imageUrl:
        'https://images.unsplash.com/photo-1505691938895-1758d7feb511?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'RO Water Service',
    category: 'Appliance',
    description: 'Filter replacement and leakage fix.',
    imageUrl:
        'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Geyser Repair',
    category: 'Appliance',
    description: 'No hot water and electrical checks.',
    imageUrl:
        'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Microwave Service',
    category: 'Appliance',
    description: 'Heating issues and parts replacement.',
    imageUrl:
        'https://images.unsplash.com/photo-1511688878353-3a2f5be94cd7?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Laptop Repair',
    category: 'Electronics',
    description: 'Battery, speed, and hardware fixes.',
    imageUrl:
        'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Phone Repair',
    category: 'Electronics',
    description: 'Screen and battery replacement.',
    imageUrl:
        'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Painting Service',
    category: 'Painting',
    description: 'Interior wall painting and touch-ups.',
    imageUrl:
        'https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Plumbing Repair',
    category: 'Plumbing',
    description: 'Leak fixes and fittings replacement.',
    imageUrl:
        'https://images.unsplash.com/photo-1564087128619-1f0e331dd1f2?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Electrical Repair',
    category: 'Electrical',
    description: 'Wiring, switch, and socket fixes.',
    imageUrl:
        'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Pest Control',
    category: 'Pest Control',
    description: 'Safe treatment for common pests.',
    imageUrl:
        'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Car Wash',
    category: 'Car Care',
    description: 'Basic exterior wash and vacuum.',
    imageUrl:
        'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Window Cleaning',
    category: 'Cleaning',
    description: 'Glass and frame cleaning.',
    imageUrl:
        'https://images.unsplash.com/photo-1497366811353-6870744d04b2?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
  _SeedService(
    name: 'Gardening Service',
    category: 'Gardening',
    description: 'Lawn care and trimming.',
    imageUrl:
        'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80',
    serviceType: 'at_customer',
  ),
];

const List<_CatalogService> _fallbackCatalogServices = <_CatalogService>[
  _CatalogService(
    name: 'Home Deep Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Residential Area',
    rating: 4.7,
    ratingCount: 82,
  ),
  _CatalogService(
    name: 'Bathroom Plumbing',
    category: 'Plumbing',
    serviceType: 'at_customer',
    location: 'Nearby City',
    rating: 4.6,
    ratingCount: 58,
  ),
  _CatalogService(
    name: 'AC Service & Repair',
    category: 'Appliance',
    serviceType: 'at_customer',
    location: 'Urban Area',
    rating: 4.8,
    ratingCount: 120,
  ),
  _CatalogService(
    name: 'Fan & Light Installation',
    category: 'Electrical',
    serviceType: 'at_customer',
    location: 'Local Service Zone',
    rating: 4.5,
    ratingCount: 73,
  ),
  _CatalogService(
    name: 'Wall Painting',
    category: 'Painting',
    serviceType: 'at_customer',
    location: 'Service Radius 15 km',
    rating: 4.4,
    ratingCount: 41,
  ),
  _CatalogService(
    name: 'Carpet Shampoo Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Home Visit',
    rating: 4.6,
    ratingCount: 36,
  ),
  _CatalogService(
    name: 'Pest Control Basic',
    category: 'Pest Control',
    serviceType: 'at_customer',
    location: 'Citywide',
    rating: 4.3,
    ratingCount: 67,
  ),
  _CatalogService(
    name: 'Washing Machine Repair',
    category: 'Appliance',
    serviceType: 'at_customer',
    location: 'Local Technician',
    rating: 4.7,
    ratingCount: 51,
  ),
  _CatalogService(
    name: 'Sofa & Upholstery Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Home Service',
    rating: 4.6,
    ratingCount: 44,
  ),
  _CatalogService(
    name: 'General Handyman',
    category: 'Repairs',
    serviceType: 'at_customer',
    location: 'Nearby',
    rating: 4.5,
    ratingCount: 95,
  ),
  _CatalogService(
    name: 'Water Tank Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Household Service',
    rating: 4.4,
    ratingCount: 32,
  ),
  _CatalogService(
    name: 'Home CCTV Setup',
    category: 'Security',
    serviceType: 'at_customer',
    location: 'Installation Support',
    rating: 4.6,
    ratingCount: 27,
  ),
  _CatalogService(
    name: 'Car Wash',
    category: 'Car Care',
    serviceType: 'at_customer',
    location: 'Doorstep Service',
    rating: 4.5,
    ratingCount: 64,
  ),
  _CatalogService(
    name: 'Car Wash Spa',
    category: 'Car Care',
    serviceType: 'at_customer',
    location: 'Premium Service',
    rating: 4.7,
    ratingCount: 52,
  ),
  _CatalogService(
    name: 'House Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Full Home',
    rating: 4.6,
    ratingCount: 110,
  ),
  _CatalogService(
    name: 'Bathroom Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Hygiene Focus',
    rating: 4.5,
    ratingCount: 74,
  ),
  _CatalogService(
    name: 'Kitchen Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Degrease Service',
    rating: 4.4,
    ratingCount: 60,
  ),
  _CatalogService(
    name: 'Sofa Cleaning',
    category: 'Cleaning',
    serviceType: 'at_customer',
    location: 'Fabric Care',
    rating: 4.6,
    ratingCount: 48,
  ),
  _CatalogService(
    name: 'RO Water Service',
    category: 'Appliance',
    serviceType: 'at_customer',
    location: 'Filter Replacement',
    rating: 4.5,
    ratingCount: 55,
  ),
  _CatalogService(
    name: 'Geyser Repair',
    category: 'Appliance',
    serviceType: 'at_customer',
    location: 'Home Visit',
    rating: 4.5,
    ratingCount: 43,
  ),
  _CatalogService(
    name: 'Microwave Service',
    category: 'Appliance',
    serviceType: 'at_customer',
    location: 'Quick Fix',
    rating: 4.4,
    ratingCount: 31,
  ),
  _CatalogService(
    name: 'Laptop Repair',
    category: 'Electronics',
    serviceType: 'at_customer',
    location: 'Pickup Available',
    rating: 4.6,
    ratingCount: 39,
  ),
  _CatalogService(
    name: 'Phone Repair',
    category: 'Electronics',
    serviceType: 'at_customer',
    location: 'Screen and Battery',
    rating: 4.5,
    ratingCount: 71,
  ),
  _CatalogService(
    name: 'Painting Service',
    category: 'Painting',
    serviceType: 'at_customer',
    location: 'Interior Walls',
    rating: 4.4,
    ratingCount: 58,
  ),
  _CatalogService(
    name: 'Plumbing Repair',
    category: 'Plumbing',
    serviceType: 'at_customer',
    location: 'Leak Fix',
    rating: 4.6,
    ratingCount: 83,
  ),
  _CatalogService(
    name: 'Electrical Repair',
    category: 'Electrical',
    serviceType: 'at_customer',
    location: 'Wiring and Switches',
    rating: 4.5,
    ratingCount: 69,
  ),
  _CatalogService(
    name: 'Pest Control',
    category: 'Pest Control',
    serviceType: 'at_customer',
    location: 'Safe Treatment',
    rating: 4.3,
    ratingCount: 56,
  ),
  _CatalogService(
    name: 'Gardening Service',
    category: 'Gardening',
    serviceType: 'at_customer',
    location: 'Lawn Care',
    rating: 4.4,
    ratingCount: 33,
  ),
];

class ViewServicesScreen extends StatefulWidget {
  const ViewServicesScreen({super.key});

  @override
  State<ViewServicesScreen> createState() => _ViewServicesScreenState();
}

class _ViewServicesScreenState extends State<ViewServicesScreen> {
  bool _seeding = false;
  bool _autoSeedChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoSeed();
    });
  }

  Future<void> _maybeAutoSeed() async {
    if (_autoSeedChecked) return;
    _autoSeedChecked = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>;
      final role = (data['role'] as String?) ?? '';
      if (role != 'Service Provider') return;

      final existing = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return;

      final providerName =
          (data['username'] as String?)?.trim().isNotEmpty == true
              ? (data['username'] as String).trim()
              : (user.displayName ?? 'Service Provider');

      if (!mounted) return;
      await _seedDemoServices(
        context: context,
        providerId: user.uid,
        providerName: providerName,
      );
    } catch (_) {
      // Auto-seed is best-effort only
    }
  }

  Future<void> _seedDemoServices({
    required BuildContext context,
    required String providerId,
    required String providerName,
  }) async {
    if (_seeding) return;
    setState(() => _seeding = true);

    try {
      final existing = await FirebaseFirestore.instance
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .where('seedTag', isEqualTo: 'demo-v1')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demo services already added.')),
          );
        }
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      final servicesRef = FirebaseFirestore.instance.collection('services');

      for (final s in _demoSeedServices) {
        final doc = servicesRef.doc();
        batch.set(doc, {
          'providerId': providerId,
          'providerName': providerName,
          'serviceName': s.name,
          'description': s.description,
          'serviceImageUrl': s.imageUrl,
          'category': s.category,
          'categoryName': s.category,
          'serviceType': s.serviceType,
          'isAvailable': true,
          'addressDisplay': 'Service at your location',
          'seedTag': 'demo-v1',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo services added successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add demo services: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Widget _buildSeedDemoBanner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = (data['role'] as String?) ?? '';
        if (role != 'Service Provider') return const SizedBox.shrink();

        final providerName =
            (data['username'] as String?)?.trim().isNotEmpty == true
                ? (data['username'] as String).trim()
                : (user.displayName ?? 'Service Provider');

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Add demo services so customers can book immediately.',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _seeding
                    ? null
                    : () => _seedDemoServices(
                          context: context,
                          providerId: user.uid,
                          providerName: providerName,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: _seeding
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Demo'),
              ),
            ],
          ),
        );
      },
    );
  }

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
            return _buildCatalogFallback(context);
          }

          // Filter out services with 'Uncategorized' category
          final services = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final category = data['category'] as String?;
            return category != 'Uncategorized' && category != 'uncategorized';
          }).toList();

          if (services.isEmpty) {
            return _buildCatalogFallback(context);
          }

          return Column(
            children: [
              _buildSeedDemoBanner(),
              Expanded(
                child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final serviceDoc = services[index];
              final serviceData = serviceDoc.data() as Map<String, dynamic>;
              final String resolvedProviderId = (serviceData['providerId'] as String?)
                      ?? (serviceData['ownerId'] as String?)
                      ?? (serviceData['uid'] as String?)
                      ?? (serviceData['userId'] as String?)
                      ?? '';

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
                  serviceId: serviceDoc.id,
                  serviceName: (serviceData['serviceName'] as String?) ?? 'No Name',
                  category: (serviceData['category'] as String?) ?? 'Uncategorized',
                  imageUrl: serviceData['serviceImageUrl'] as String?,
                  providerId: resolvedProviderId,
                  serviceType: serviceData['serviceType'],
                  location: (serviceData['addressDisplay'] as String?) ?? (serviceData['locationAddress'] as String?),
                  isAvailable: (serviceData['isAvailable'] is bool) ? serviceData['isAvailable'] as bool : null,
                  subCategoryNames: (serviceData['subCategoryNames'] is List)
                      ? (serviceData['subCategoryNames'] as List)
                          .whereType<String>()
                          .toList()
                      : null,
                  rating: ((serviceData['rating'] ?? serviceData['avgRating']) is num)
                      ? ((serviceData['rating'] ?? serviceData['avgRating']) as num).toDouble()
                      : null,
                  ratingCount: (serviceData['ratingCount'] is num)
                      ? (serviceData['ratingCount'] as num).toInt()
                      : null,
                ),
              );

              // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
            },
          ),
        ),
      ],
    );
        },
      ),
    );
  }

  Widget _buildCatalogFallback(BuildContext context) {
    return Column(
      children: [
        _buildSeedDemoBanner(),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: Text(
            'Live provider services are currently limited. Showing expanded service catalog.',
            style: TextStyle(
              color: Colors.deepPurple.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: _fallbackCatalogServices.length,
            itemBuilder: (context, index) {
              final service = _fallbackCatalogServices[index];
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${service.name} is available in catalog mode. A provider listing is required to book.',
                      ),
                    ),
                  );
                },
                child: ServiceCard(
                  serviceId: 'catalog-$index',
                  serviceName: service.name,
                  category: service.category,
                  providerId: '',
                  serviceType: service.serviceType,
                  location: service.location,
                  rating: service.rating,
                  ratingCount: service.ratingCount,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final String providerId;
  const _AvailabilityBadge({required this.providerId});

  @override
  Widget build(BuildContext context) {
    if (providerId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .collection('availability')
          .doc('settings')
          .snapshots(),
      builder: (context, snapshot) {
        bool on;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final bool? isAvailable = data['isAvailableNow'] as bool?;
          on = isAvailable == true;
        } else {
          // Default visible state until settings are saved or stream resolves
          on = false;
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: on ? Colors.green.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            on ? 'Available' : 'On Leave',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class _ServiceRatingRow extends StatelessWidget {
  final String serviceId;
  final double? rating;
  final int? ratingCount;

  const _ServiceRatingRow({
    required this.serviceId,
    required this.rating,
    required this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    if (rating != null) {
      return _buildStarsRow(context, rating!, ratingCount);
    }

    // Fallback: derive rating from serviceReviews collection when aggregate is missing.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceReviews')
          .where('serviceId', isEqualTo: serviceId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: const [
              Icon(Icons.star_border, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ],
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Row(
            children: [
              const Icon(Icons.star_border, size: 14, color: Colors.grey),
              const SizedBox(width: 2),
              Text(
                'No ratings',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        }

        double total = 0;
        int count = 0;
        for (final d in snapshot.data!.docs) {
          final m = d.data() as Map<String, dynamic>;
          final r = (m['rating'] as num?)?.toDouble();
          if (r != null) {
            total += r;
            count++;
          }
        }

        if (count == 0) {
          return Row(
            children: [
              const Icon(Icons.star_border, size: 14, color: Colors.grey),
              const SizedBox(width: 2),
              Text(
                'No ratings',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        }

        final avg = total / count;
        return _buildStarsRow(context, avg, count);
      },
    );
  }

  Widget _buildStarsRow(BuildContext context, double value, int? count) {
    final r = value.clamp(0, 5);
    final whole = r.floor();
    final hasHalf = (r - whole) >= 0.5;

    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < whole) {
            return const Icon(Icons.star, size: 14, color: Colors.amber);
          } else if (i == whole && hasHalf) {
            return const Icon(Icons.star_half, size: 14, color: Colors.amber);
          } else {
            return const Icon(Icons.star_border, size: 14, color: Colors.amber);
          }
        }),
        const SizedBox(width: 4),
        Text(
          r.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 11,
            color: Colors.amber[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count != null) ...[
          Text(
            ' ($count)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// --- The ServiceCard and ProviderInfoChip widgets remain unchanged below ---

class ServiceCard extends StatelessWidget {
  final String serviceId;
  final String serviceName;
  final String category;
  final String? imageUrl;
  final String providerId;
  final String? serviceType; // at_provider | at_customer | remote
  final String? location;
  final bool? isAvailable;
  final List<String>? subCategoryNames;
  final double? rating;
  final int? ratingCount;

  const ServiceCard({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.category,
    this.imageUrl,
    required this.providerId,
    this.serviceType,
    this.location,
    this.isAvailable,
    this.subCategoryNames,
    this.rating,
    this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.grey[200]),
                if (imageUrl is String && (imageUrl as String).isNotEmpty)
                  Image.network(
                    imageUrl as String,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      return progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.grey, size: 40);
                    },
                  )
                else
                  const Center(child: Icon(Icons.work, color: Colors.grey, size: 40)),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _AvailabilityBadge(providerId: providerId),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _ServiceRatingRow(
                    serviceId: serviceId,
                    rating: rating,
                    ratingCount: ratingCount,
                  ),
                  if (subCategoryNames != null && subCategoryNames!.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 0,
                      children: subCategoryNames!
                          .take(2)
                          .map((s) => Chip(
                                label: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ))
                          .toList(),
                    ),
                  if (location != null && location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 14, color: Colors.deepPurple),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ProviderInfoChip(providerId: providerId),
                      if (serviceType is String && (serviceType as String).isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _ServiceTypeChip(type: serviceType as String),
                      ],
                    ],
                  ),
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
    if (providerId.isEmpty) {
      return const Text('By: Unknown',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic));
    }
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(providerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('By: Unknown',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic));
        }

        final providerData = snapshot.data!.data() as Map<String, dynamic>;
        final String providerName = (providerData['username'] as String?)?.trim().isNotEmpty == true
            ? (providerData['username'] as String).trim()
            : 'Service Provider';
        final String? profilePicUrl = providerData['profileImageUrl'];

        return Chip(
          avatar: CircleAvatar(
            backgroundColor: Colors.deepPurple.shade100,
            backgroundImage: profilePicUrl != null && profilePicUrl.isNotEmpty
                ? NetworkImage(profilePicUrl)
                : null,
            child: (profilePicUrl == null || profilePicUrl.isEmpty)
                ? Text(providerName.isNotEmpty ? providerName.substring(0, 1) : '?')
                : null,
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

class _ServiceTypeChip extends StatelessWidget {
  final String type;
  const _ServiceTypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    String label = 'Location';
    Color color = Colors.blueGrey.shade100;
    Color textColor = Colors.black87;
    if (type == 'remote') {
      label = 'Remote';
      color = Colors.teal.shade100;
    } else if (type == 'at_provider') {
      label = 'At Provider';
      color = Colors.indigo.shade100;
    } else if (type == 'at_customer') {
      label = 'At Customer';
      color = Colors.orange.shade100;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w600)),
    );
  }
}
