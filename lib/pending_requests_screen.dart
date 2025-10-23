import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PendingRequestsScreen extends StatelessWidget {
  const PendingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .where('providerId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('scheduledDateTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending requests found.'));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _PendingRequestCard(docId: doc.id, data: data);
            },
          );
        },
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _PendingRequestCard({required this.docId, required this.data});

  Future<void> _updateRequestStatus(String newStatus) async {
    final Map<String, dynamic> updates = {'status': newStatus};
    if (newStatus == 'accepted') {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'completed') {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }

    final docRef = FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(docId);

    try {
      // Ensure current user is the assigned provider (defensive check)
      try {
        final snap = await docRef.get();
        final data = snap.data() as Map<String, dynamic>?;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (data == null || uid == null || (data['providerId']?.toString() != uid && data['customerId']?.toString() != uid)) {
          throw FirebaseException(plugin: 'cloud_firestore', message: 'Not authorized to update this booking');
        }
      } catch (e) {
        rethrow;
      }

      // Ensure a trackingId exists when accepting
      if (newStatus == 'accepted') {
        try {
          final current = await docRef.get();
          final data = current.data() as Map<String, dynamic>?;
          final existing = data?['trackingId']?.toString();
          if (existing == null || existing.isEmpty) {
            final now = DateTime.now();
            final code = 'SRV-${now.year.toString().padLeft(4,'0')}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${docId.substring(0, 6).toUpperCase()}';
            updates['trackingId'] = code;
          }
        } catch (_) {}
      }

      await docRef.update(updates);
    } catch (e) {
      // Bubble up for UI to show error via caller context
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = (data['scheduledDateTime'] as Timestamp).toDate();
    final scheduledDateStr = DateFormat.yMMMd().format(scheduled);
    final scheduledTimeStr = DateFormat.jm().format(scheduled);

    DateTime? requestedDate;
    String? requestedDateStr;
    String? requestedTimeStr;
    final bookingTs = data['bookingTimestamp'];
    if (bookingTs is Timestamp) {
      requestedDate = bookingTs.toDate();
      requestedDateStr = DateFormat.yMMMd().format(requestedDate);
      requestedTimeStr = DateFormat.jm().format(requestedDate);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['serviceName'] ?? 'No Service Name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            _PendingCustomerDetailsSection(
              customerId: data['customerId'],
              fallbackName: data['customerName'] ?? 'Customer',
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.event, text: '$scheduledDateStr at $scheduledTimeStr'),
            if (requestedDateStr != null && requestedTimeStr != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: _InfoRow(
                  icon: Icons.schedule,
                  text: 'Requested: $requestedDateStr at $requestedTimeStr',
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _updateRequestStatus('rejected'),
                  child: const Text('Reject', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _updateRequestStatus('accepted'),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingCustomerDetailsSection extends StatelessWidget {
  final String customerId;
  final String fallbackName;
  const _PendingCustomerDetailsSection({required this.customerId, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        String displayName = fallbackName;
        String? email;
        String? phone;
        String? address;
        String? profileImageUrl;
        GeoPoint? geo;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data()!;
          final username = data['username'] as String?;
          if (username != null && username.trim().isNotEmpty) displayName = username;
          email = data['email'] as String?;
          phone = data['phone'] as String?;
          address = data['address'] as String?;
          profileImageUrl = data['profileImageUrl'] as String?;
          final locField = data['location'];
          if (locField is GeoPoint) geo = locField;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage:
                      (profileImageUrl != null && profileImageUrl!.isNotEmpty) ? NetworkImage(profileImageUrl!) : null,
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                      if (email != null && email!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(email!, style: TextStyle(color: Colors.grey[700], fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                      if (phone != null && phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(phone!, style: TextStyle(color: Colors.grey[700], fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if ((address != null && address!.isNotEmpty) || geo != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (address != null && address!.isNotEmpty) ? address! : 'Location available',
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'View on map',
                    icon: const Icon(Icons.map_outlined),
                    color: Colors.deepPurple,
                    onPressed: () => _openInMaps(context, geo: geo, address: address ?? ''),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openInMaps(BuildContext context, {GeoPoint? geo, String? address}) async {
    final List<Uri> candidates = [
      if (geo != null) Uri.parse('geo:${geo.latitude},${geo.longitude}?q=${geo.latitude},${geo.longitude}(Customer)'),
      if (address != null && address.isNotEmpty) Uri.parse('geo:0,0?q=${Uri.encodeComponent(address!)}'),
      if (geo != null) Uri.parse('google.navigation:q=${geo.latitude},${geo.longitude}&mode=d'),
      if (address != null && address.isNotEmpty) Uri.parse('google.navigation:q=${Uri.encodeComponent(address!)}&mode=d'),
      if (geo != null) Uri.parse('https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}'),
      if (address != null && address.isNotEmpty) Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address!)}'),
    ];
    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return;
          final launchedAlt = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (launchedAlt) return;
        }
      } catch (_) {}
    }
    // As a last resort, try to open in platform default even if canLaunchUrl failed (for web links)
    final Uri webUri = (geo != null)
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address ?? '')}');
    await launchUrl(webUri, mode: LaunchMode.platformDefault);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}
