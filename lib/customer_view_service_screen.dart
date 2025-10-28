// lib/customer_view_service_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/booking_confirmation_screen.dart'; // <-- IMPORT the new screen
import 'package:url_launcher/url_launcher.dart';

class CustomerViewServiceScreen extends StatelessWidget {
  final String serviceId;
  final ValueNotifier<bool> _termsAccepted = ValueNotifier<bool>(false);

  CustomerViewServiceScreen({super.key, required this.serviceId});

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
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.1),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
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
                        decoration: const BoxDecoration(
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
                    context: context,
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
                    _buildServiceAreasCard(context, serviceAreas),
                  ],
                  if (terms != null && terms.isNotEmpty) ...[
                    _buildTermsHeader(context),
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

  Widget _buildOverviewCard({required BuildContext context, String? categoryName, List<String>? subCategoryNames, bool? isAvailable}) {
    final subs = (subCategoryNames ?? const <String>[]).where((s) => s.trim().isNotEmpty).toList();
    final visible = subs.take(6).toList();
    final extraCount = subs.length - visible.length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Service Category',
                    style: TextStyle(fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${subs.length}', style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Prominent category pill
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade400]),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.label_important, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    (categoryName ?? 'Uncategorized'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (subs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...visible.map((s) => Chip(
                        avatar: const Icon(Icons.local_offer, size: 16, color: Colors.deepPurple),
                        label: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: Colors.deepPurple.shade50,
                      )),
                  if (extraCount > 0)
                    ActionChip(
                      avatar: const Icon(Icons.more_horiz, size: 16, color: Colors.deepPurple),
                      label: Text('+$extraCount more'),
                      onPressed: () => _showAllSubcategories(context, subs),
                      backgroundColor: Colors.deepPurple.shade50,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAllSubcategories(BuildContext context, List<String> subs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category_outlined, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('All Subcategories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subs.map((s) => Chip(
                        avatar: const Icon(Icons.local_offer, size: 16, color: Colors.deepPurple),
                        label: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: Colors.deepPurple.shade50,
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              Row(
                children: [
                  const Icon(Icons.phone, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  const Text('Phone', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: 'Call',
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () => _launchPhone(phone),
                  ),
                  IconButton(
                    tooltip: 'Message',
                    icon: const Icon(Icons.sms_rounded, color: Colors.blueAccent),
                    onPressed: () => _launchSms(phone),
                  ),
                ],
              ),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: 'Send email',
                    icon: const Icon(Icons.send_rounded, color: Colors.deepPurple),
                    onPressed: () => _launchEmail(email),
                  ),
                ],
              ),
            ],
            if (website != null && website.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.link, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  const Text('Website', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(website, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: 'Open website',
                    icon: const Icon(Icons.public, color: Colors.indigo),
                    onPressed: () => _launchWebsite(website),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchSms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchWebsite(String url) async {
    final fixed = _ensureHttp(url);
    final uri = Uri.parse(fixed);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _ensureHttp(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return 'https://$url';
  }

  Widget _buildServiceAreasCard(BuildContext context, List<String> areas) {
    final visible = areas.take(8).toList();
    final extraCount = areas.length - visible.length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_rounded, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Covered Areas',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${areas.length}', style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                if (extraCount > 0)
                  TextButton(
                    onPressed: () => _showAllAreas(context, areas),
                    child: Text('View all', style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...visible.map((a) => Chip(
                      avatar: const Icon(Icons.location_on, size: 16, color: Colors.deepPurple),
                      label: Text(a, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: Colors.deepPurple.shade50,
                    )),
                if (extraCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.more_horiz, size: 16, color: Colors.deepPurple),
                    label: Text('+$extraCount more'),
                    onPressed: () => _showAllAreas(context, areas),
                    backgroundColor: Colors.deepPurple.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAllAreas(BuildContext context, List<String> areas) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map_rounded, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('All Service Areas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: areas.map((a) => Chip(
                        avatar: const Icon(Icons.location_on, size: 16, color: Colors.deepPurple),
                        label: Text(a, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: Colors.deepPurple.shade50,
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermsCard(String terms) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          terms,
          style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.6),
          textAlign: TextAlign.start,
        ),
      ),
    );
  }

  Widget _buildTermsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Terms & Conditions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _termsAccepted,
            builder: (_, accepted, __) {
              return IconButton(
                tooltip: accepted ? 'Accepted' : 'Accept terms',
                onPressed: () {
                  final next = !accepted;
                  _termsAccepted.value = next;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(next ? 'Terms & Conditions accepted' : 'Terms & Conditions unaccepted')),
                  );
                },
                icon: Icon(
                  accepted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: accepted ? Colors.green : Colors.grey,
                ),
              );
            },
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.grey[900],
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(String description) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          description,
          style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.65),
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.06),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.06),
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
              Text(addressDisplay, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
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
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.12),
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
        icon: const Icon(Icons.calendar_month_rounded),
        label: const Text("Book This Service", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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