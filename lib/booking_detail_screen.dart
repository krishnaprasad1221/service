// lib/booking_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailScreen extends StatelessWidget {
  final String requestId;
  const BookingDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Request not found'));
          }

          final data = snap.data!.data()!;
          final String status = (data['status'] ?? 'pending').toString();
          final String serviceName = (data['serviceName'] ?? '').toString();
          final String? description =
              (data['description'] ?? data['notes'])?.toString();

          final Timestamp? scheduledTs =
              data['scheduledDateTime'] as Timestamp?;
          final Timestamp? createdTs =
              data['bookingTimestamp'] as Timestamp?;
          final Timestamp? acceptedTs = data['acceptedAt'] as Timestamp?;
          final Timestamp? completedTs = data['completedAt'] as Timestamp?;
          final double? quotedAmount = _toDouble(data['quotedAmount']);
          final double? finalAmount = _toDouble(data['finalAmount']);

          // Address from either flat field or nested snapshot
          final String? address =
              (data['addressSnapshot'] is Map<String, dynamic>)
                  ? ((
                              (data['addressSnapshot']['addressLine'] ?? '')
                          as String) +
                      (((data['addressSnapshot']['city'] ?? '') as String)
                              .isNotEmpty
                          ? ', ${data['addressSnapshot']['city']}'
                          : '') +
                      (((data['addressSnapshot']['pincode'] ?? '') as String)
                              .isNotEmpty
                          ? ', ${data['addressSnapshot']['pincode']}'
                          : '') +
                      (((data['addressSnapshot']['landmark'] ?? '') as String)
                              .isNotEmpty
                          ? '\nLandmark: ${data['addressSnapshot']['landmark']}'
                          : '')).trim()
                  : data['address']?.toString();

          // Geo from geoSnapshot or location
          final GeoPoint? geo = (data['geoSnapshot'] is GeoPoint)
              ? data['geoSnapshot'] as GeoPoint
              : (data['location'] is GeoPoint
                  ? data['location'] as GeoPoint
                  : null);

          // Estimated duration supports multiple field names
          final String? estimatedDuration = _pickFirstString([
            data['estimatedDuration'],
            data['estimated_time'],
            data['timeEstimate'],
            data['duration'],
            data['expectedDuration'],
            data['durationText'],
            (data['durationMinutes'] != null)
                ? '${data['durationMinutes']} mins'
                : null,
            (data['estimatedDurationDays'] != null)
                ? '${data['estimatedDurationDays']} day(s)'
                : null,
          ]);

          // Additional job fields (optional)
          final String? jobCategory = data['category']?.toString();
          final String? jobSubcategory = data['subcategory']?.toString();
          final String? additionalNotes = data['additionalNotes']?.toString();

          // Photos from either imageUrls or attachments
          final List<String> attachments = [
            ...(((data['imageUrls'] as List?) ?? const [])
                .map((e) => e?.toString())
                .whereType<String>()),
            ...(((data['attachments'] as List?) ?? const [])
                .map((e) => e?.toString())
                .whereType<String>()),
          ];

          // Contact details captured at booking time
          final Map<String, dynamic>? contact =
              data['contact'] is Map<String, dynamic>
                  ? (data['contact'] as Map<String, dynamic>)
                  : null;
          final String? contactName =
              contact != null ? contact['name']?.toString() : null;
          final String? contactPhone =
              contact != null ? contact['phone']?.toString() : null;

          final String customerId = (data['customerId'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: serviceName.isNotEmpty
                    ? serviceName
                    : 'Service Request',
                trailing: _StatusChip(status: status),
                children: [
                  if (description != null && description.trim().isNotEmpty)
                    _InfoRow(
                        icon: Icons.notes,
                        label: 'Description',
                        value: description),
                  if (jobCategory != null && jobCategory.isNotEmpty)
                    _InfoRow(
                        icon: Icons.category,
                        label: 'Category',
                        value: jobCategory),
                  if (jobSubcategory != null && jobSubcategory.isNotEmpty)
                    _InfoRow(
                        icon: Icons.label_important_outline,
                        label: 'Subcategory',
                        value: jobSubcategory),
                  if (quotedAmount != null)
                    _InfoRow(
                        icon: Icons.request_quote,
                        label: 'Quoted Amount',
                        value: quotedAmount.toStringAsFixed(2)),
                  if (finalAmount != null)
                    _InfoRow(
                        icon: Icons.payments,
                        label: 'Final Amount',
                        value: finalAmount.toStringAsFixed(2)),
                  if (estimatedDuration != null &&
                      estimatedDuration.isNotEmpty)
                    _InfoRow(
                        icon: Icons.timer,
                        label: 'Estimated Duration',
                        value: estimatedDuration),
                  if (scheduledTs != null)
                    _InfoRow(
                      icon: Icons.event,
                      label: 'Scheduled',
                      value:
                          '${DateFormat.yMMMd().format(scheduledTs.toDate())} • ${DateFormat.jm().format(scheduledTs.toDate())}',
                    ),
                  if (createdTs != null)
                    _InfoRow(
                      icon: Icons.schedule,
                      label: 'Requested',
                      value:
                          '${DateFormat.yMMMd().format(createdTs.toDate())} • ${DateFormat.jm().format(createdTs.toDate())}',
                    ),
                  if (acceptedTs != null)
                    _InfoRow(
                        icon: Icons.task_alt,
                        label: 'Accepted at',
                        value: DateFormat.yMMMd()
                            .add_jm()
                            .format(acceptedTs.toDate())),
                  if (completedTs != null)
                    _InfoRow(
                        icon: Icons.check_circle,
                        label: 'Completed at',
                        value: DateFormat.yMMMd()
                            .add_jm()
                            .format(completedTs.toDate())),
                  if (additionalNotes != null &&
                      additionalNotes.trim().isNotEmpty)
                    _InfoRow(
                        icon: Icons.description_outlined,
                        label: 'Additional Notes',
                        value: additionalNotes),
                ],
              ),

              const SizedBox(height: 12),

              // Customer (live from users collection) + quick contact actions
              _UserSection(userId: customerId, title: 'Customer'),

              const SizedBox(height: 12),

              // Contact provided in booking (snapshot of who to reach on site)
              if ((contactName != null && contactName.isNotEmpty) ||
                  (contactPhone != null && contactPhone.isNotEmpty))
                _SectionCard(
                  title: 'On-site Contact',
                  children: [
                    if (contactName != null && contactName.isNotEmpty)
                      _InfoRow(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: contactName),
                    if (contactPhone != null && contactPhone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.call, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(contactPhone,
                                  style: const TextStyle(fontSize: 15))),
                          TextButton.icon(
                            onPressed: () => _callPhone(contactPhone),
                            icon: const Icon(Icons.phone),
                            label: const Text('Call'),
                          ),
                        ],
                      ),
                  ],
                ),

              const SizedBox(height: 12),

              // Location
              _SectionCard(
                title: 'Location',
                children: [
                  if (address != null && address.isNotEmpty)
                    _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: address),
                  if (geo != null)
                    Row(
                      children: [
                        const Icon(Icons.map, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Lat: ${geo.latitude.toStringAsFixed(5)}, '
                          'Lng: ${geo.longitude.toStringAsFixed(5)}',
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _openMap(address: address, geo: geo),
                          icon: const Icon(Icons.directions),
                          label: const Text('Open'),
                        ),
                      ],
                    ),
                ],
              ),

              // Attachments
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Attachments',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: attachments
                          .map((url) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Actions
              _ActionRow(requestId: requestId, status: status),
            ],
          );
        },
      ),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _pickFirstString(List<dynamic?> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString();
      if (s.trim().isNotEmpty) return s;
    }
    return null;
  }

  Future<void> _openMap({String? address, GeoPoint? geo}) async {
    final String? query = geo != null
        ? '${geo.latitude},${geo.longitude}'
        : (address != null && address.isNotEmpty ? address : null);
    if (query == null) return;

    final List<Uri> candidates = [
      if (geo != null)
        Uri.parse(
            'geo:${geo.latitude},${geo.longitude}?q=${geo.latitude},${geo.longitude}(Customer)'),
      if (address != null && address.isNotEmpty)
        Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}'),
      if (geo != null)
        Uri.parse('google.navigation:q=${geo.latitude},${geo.longitude}&mode=d'),
      if (address != null && address.isNotEmpty)
        Uri.parse(
            'google.navigation:q=${Uri.encodeComponent(address)}&mode=d'),
      Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}'),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched =
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return;
        }
      } catch (_) {}
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'accepted':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
        break;
    }
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _SectionCard(
      {required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSection extends StatelessWidget {
  final String userId;
  final String title;
  const _UserSection({required this.userId, required this.title});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        String? username;
        String? email;
        String? phone;
        String? address;
        String? profileImageUrl;
        if (snap.hasData && snap.data!.data() != null) {
          final data = snap.data!.data()!;
          username = data['username']?.toString();
          email = data['email']?.toString();
          phone = data['phone']?.toString();
          address = data['address']?.toString();
          profileImageUrl = data['profileImageUrl']?.toString();
        }
        return _SectionCard(
          title: title,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage:
                      (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                          ? NetworkImage(profileImageUrl!)
                          : null,
                  child: (profileImageUrl == null ||
                          profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username ?? 'User',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      if (email != null && email!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(email!,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13)),
                        ),
                      if (phone != null && phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(phone!,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 13)),
                        ),
                      if (address != null && address!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(address!,
                              style: const TextStyle(fontSize: 13)),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (phone != null && phone!.isNotEmpty)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Call'),
                              onPressed: () => _call(phone!),
                            ),
                          if (email != null && email!.isNotEmpty)
                            OutlinedButton.icon(
                              icon:
                                  const Icon(Icons.email_outlined, size: 18),
                              label: const Text('Email'),
                              onPressed: () => _email(email!),
                            ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _email(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ActionRow extends StatelessWidget {
  final String requestId;
  final String status;
  const _ActionRow({required this.requestId, required this.status});

  Future<void> _update(String newStatus) async {
    final updates = <String, dynamic>{'status': newStatus};
    if (newStatus == 'accepted') {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'completed') {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    await FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(requestId)
        .update(updates);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(requestId)
          .get();
      final data = snap.data() as Map<String, dynamic>?;
      final customerId = data?['customerId'] as String?;
      final serviceName =
          (data?['serviceName'] as String?) ?? 'Your booking';
      if (customerId != null && customerId.isNotEmpty) {
        String title, body;
        switch (newStatus) {
          case 'accepted':
            title = 'Booking accepted';
            body = 'Your request for $serviceName was accepted';
            break;
          case 'completed':
            title = 'Booking completed';
            body = '$serviceName has been marked completed';
            break;
          case 'rejected':
            title = 'Booking rejected';
            body = 'Your request for $serviceName was rejected';
            break;
          default:
            title = 'Booking update';
            body = 'Status changed to $newStatus for $serviceName';
        }
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': customerId,
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'type': 'booking_status',
          'title': title,
          'body': body,
          'relatedId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => _update('rejected'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _update('accepted'),
            child: const Text('Accept'),
          ),
        ],
      );
    } else if (status == 'accepted') {
      return Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Mark as Complete'),
          onPressed: () => _update('completed'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      );
    } else {
      return const Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.check_circle, color: Colors.green),
      );
    }
  }
}