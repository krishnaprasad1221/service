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
          final String serviceName = (data['serviceName'] as String?) ?? 'Service';
          final String? imageUrl = data['serviceImageUrl'] as String?;
          final String description = (data['description'] as String?) ?? 'No description available.';
          final String providerId = (data['providerId'] as String?) ?? '';
          final String? serviceType = data['serviceType'] as String?;
          final String? addressDisplay = (data['addressDisplay'] as String?) ?? (data['locationAddress'] as String?);
          final String? categoryName = data['categoryName'] as String? ?? data['category'] as String?;
          final List<String> subCategoryNames = (data['subCategoryNames'] is List)
              ? (data['subCategoryNames'] as List).whereType<String>().toList()
              : <String>[];
          final bool? isAvailable = (data['isAvailable'] is bool) ? data['isAvailable'] as bool : null;
          final String? contactPhone = data['contactPhone'] as String?;
          final String? contactEmail = data['contactEmail'] as String?;
          final String? websiteUrl = data['websiteUrl'] as String?;
          final List<String> serviceAreas = (data['serviceAreas'] is List)
              ? (data['serviceAreas'] as List).whereType<String>().toList()
              : <String>[];
          final String? terms = data['terms'] as String?;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: Colors.deepPurple,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    serviceName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
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
                            colors: [Colors.black54, Colors.transparent],
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: _AvailabilityBadge(providerId: providerId),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildOverviewCard(
                    categoryName: categoryName,
                    subCategoryNames: subCategoryNames,
                    isAvailable: isAvailable,
                  ),
                  _buildSectionTitle("Description"),
                  _buildDescriptionCard(description),
                  _buildProviderInfoCard(providerId),
                  if (serviceType != null || addressDisplay != null) ...[
                    _buildSectionTitle("Location"),
                    _buildLocationCard(serviceType: serviceType, addressDisplay: addressDisplay),
                  ],
                  if ((contactPhone != null && contactPhone.isNotEmpty) ||
                      (contactEmail != null && contactEmail.isNotEmpty) ||
                      (websiteUrl != null && websiteUrl.isNotEmpty)) ...[
                    _buildSectionTitle("Contact"),
                    _buildContactCard(phone: contactPhone, email: contactEmail, website: websiteUrl),
                  ],
                  if (serviceAreas.isNotEmpty) ...[
                    _buildSectionTitle("Service Areas"),
                    _buildServiceAreasCard(serviceAreas),
                  ],
                  if (terms != null && terms.isNotEmpty) ...[
                    _buildSectionTitle("Terms"),
                    _buildTermsCard(terms),
                  ],
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

  Widget _buildOverviewCard({String? categoryName, List<String>? subCategoryNames, bool? isAvailable}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    categoryName ?? 'Uncategorized',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (subCategoryNames != null && subCategoryNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: subCategoryNames.take(3).map((s) => Chip(
                      label: Text(s, overflow: TextOverflow.ellipsis),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({String? phone, String? email, String? website}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (phone != null && phone.isNotEmpty)
              _infoRow(icon: Icons.phone, label: 'Phone', value: phone),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(icon: Icons.email_outlined, label: 'Email', value: email),
            ],
            if (website != null && website.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(icon: Icons.link, label: 'Website', value: website),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceAreasCard(List<String> areas) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 0,
          children: areas.take(6).map((a) => Chip(
                label: Text(a, overflow: TextOverflow.ellipsis),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )).toList(),
        ),
      ),
    );
  }

  Widget _buildTermsCard(String terms) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(terms, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.deepPurple),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
        final String providerName = (providerData['username'] as String?)?.trim().isNotEmpty == true
            ? (providerData['username'] as String).trim()
            : 'Service Provider';
        final String? profilePicUrl = providerData['profileImageUrl'] as String?;
        final String? providerAddress = providerData['address'] as String?;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: (profilePicUrl != null && profilePicUrl.isNotEmpty) ? NetworkImage(profilePicUrl) : null,
              child: profilePicUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(providerName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: providerAddress == null || providerAddress.isEmpty
                ? const Text("Verified Provider")
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Verified Provider"),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.deepPurple),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Address provided by service provider",
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(providerAddress, style: const TextStyle(fontSize: 13)),
                  ],
                ),
          ),
        );
      },
    );
  }

  Widget _buildLocationCard({String? serviceType, String? addressDisplay}) {
    String typeLabel = 'Location';
    if (serviceType == 'remote') typeLabel = 'Remote';
    if (serviceType == 'at_provider') typeLabel = 'At Provider';
    if (serviceType == 'at_customer') typeLabel = 'At Customer';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (addressDisplay != null && addressDisplay.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(addressDisplay, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            ],
          ],
        ),
      ),
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
          on = false; // default to On Leave until settings exist
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Colors.green.withOpacity(0.9) : Colors.orange.withOpacity(0.9),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(on ? Icons.check_circle : Icons.pause_circle_filled, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                on ? 'Available' : 'On Leave',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}