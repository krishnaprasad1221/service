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

          // Filter out services with 'Uncategorized' category
          final services = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final category = data['category'] as String?;
            return category != 'Uncategorized' && category != 'uncategorized';
          }).toList();

          if (services.isEmpty) {
            return const Center(
              child: Text(
                'No services available.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return GridView.builder(
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
          );
        },
      ),
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