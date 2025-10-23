// lib/booking_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'take_complaint_statement_screen.dart';
import 'create_billing_screen.dart';
// ServiceTimelineWidget removed from provider booking details

class BookingDetailScreen extends StatelessWidget {
  final String requestId;
  const BookingDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(requestId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Request not found')),
          );
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
          final Timestamp? paymentRequestedTs = data['paymentRequestedAt'] as Timestamp?;
          final Timestamp? paidTs = data['paidAt'] as Timestamp?;
          final double? quotedAmount = _toDouble(data['quotedAmount']);
          final double? finalAmount = _toDouble(data['finalAmount']);
          // trackingId removed

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
          final bool onTime = (data['onTime'] == true);
          final String? estimatedDuration = onTime
              ? 'On Time'
              : _pickFirstString([
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Booking Details'),
            backgroundColor: Colors.deepPurple,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary banner
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.assignment_turned_in, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName.isNotEmpty ? serviceName : 'Service Request',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (scheduledTs != null)
                            Text(
                              'Scheduled • '
                              '${DateFormat.yMMMd().format(scheduledTs.toDate())} · '
                              '${DateFormat.jm().format(scheduledTs.toDate())}',
                              style: TextStyle(color: Colors.white.withOpacity(0.9)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(status: status),
                  ],
                ),
              ),

              const SizedBox(height: 14),
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
                  if (status == 'pending' && estimatedDuration != null && estimatedDuration.isNotEmpty)
                    _InfoRow(
                        icon: Icons.timer,
                        label: 'Estimated Duration',
                        value: estimatedDuration),
                  // Tracking ID removed from UI
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

              // Timeline removed on provider booking details

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

              // Separate Visit Actions section (independent from Accept in bottom bar)
              _SectionCard(
                title: 'Visit Actions',
                children: [
                  Builder(builder: (context) {
                    Future<void> _updateInline(String newStatus) async {
                      final updates = <String, dynamic>{'status': newStatus};
                      if (newStatus == 'accepted') updates['acceptedAt'] = FieldValue.serverTimestamp();
                      if (newStatus == 'on_the_way') updates['onTheWayAt'] = FieldValue.serverTimestamp();
                      if (newStatus == 'arrived') updates['arrivedAt'] = FieldValue.serverTimestamp();
                      if (newStatus == 'on_the_way' || newStatus == 'arrived') {
                        updates['providerId'] = FirebaseAuth.instance.currentUser?.uid;
                        updates['acceptedAt'] = FieldValue.serverTimestamp();
                      }
                      final reqRef = FirebaseFirestore.instance.collection('serviceRequests').doc(requestId);
                      try {
                        await reqRef.update(updates);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                        }
                        return;
                      }
                      try {
                        final snap = await reqRef.get();
                        final data = snap.data() as Map<String, dynamic>?;
                        final customerId = data?['customerId'] as String?;
                        final serviceName = (data?['serviceName'] as String?) ?? 'Your booking';
                        if (customerId != null && customerId.isNotEmpty) {
                          String title, body;
                          switch (newStatus) {
                            case 'accepted':
                              title = 'Booking accepted';
                              body = 'Your request for $serviceName was accepted';
                              break;
                            case 'on_the_way':
                              title = 'On the way';
                              body = 'Provider is on the way for $serviceName';
                              break;
                            case 'arrived':
                              title = 'Arrived';
                              body = 'Provider has arrived for $serviceName';
                              break;
                            case 'completed':
                              title = 'Booking completed';
                              final ts = data?['completedAt'];
                              if (ts is Timestamp) {
                                body = '$serviceName has been marked completed on ' + DateFormat.yMMMd().add_jm().format(ts.toDate());
                              } else {
                                body = '$serviceName has been marked completed';
                              }
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

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.directions_car, size: 18),
                          label: const Text('Start Journey'),
                          onPressed: (status == 'pending')
                              ? () => _updateInline('on_the_way')
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Start Journey is available only when the booking is pending.')),
                                  );
                                },
                          style: ButtonStyle(
                            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            side: MaterialStateProperty.all(const BorderSide(color: Colors.deepPurple)),
                            foregroundColor: MaterialStateProperty.resolveWith((states) {
                              if (status == 'on_the_way') return Colors.deepPurple;
                              if (states.contains(MaterialState.pressed)) return Colors.deepPurple;
                              return null;
                            }),
                            backgroundColor: MaterialStateProperty.resolveWith((states) {
                              if (status == 'on_the_way') return Colors.deepPurple.withOpacity(0.10);
                              if (states.contains(MaterialState.pressed)) return Colors.deepPurple.withOpacity(0.08);
                              return null;
                            }),
                            overlayColor: MaterialStateProperty.all(Colors.deepPurple.withOpacity(0.12)),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.place, size: 18),
                          label: const Text('Mark Arrived'),
                          onPressed: (status == 'on_the_way' || status == 'pending')
                              ? () => _updateInline('arrived')
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Mark Arrived is available when pending or on the way.')),
                                  );
                                },
                          style: ButtonStyle(
                            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            side: MaterialStateProperty.all(const BorderSide(color: Colors.teal)),
                            foregroundColor: MaterialStateProperty.resolveWith((states) {
                              if (status == 'arrived') return Colors.teal;
                              if (states.contains(MaterialState.pressed)) return Colors.teal;
                              return null;
                            }),
                            backgroundColor: MaterialStateProperty.resolveWith((states) {
                              if (status == 'arrived') return Colors.teal.withOpacity(0.10);
                              if (states.contains(MaterialState.pressed)) return Colors.teal.withOpacity(0.08);
                              return null;
                            }),
                            overlayColor: MaterialStateProperty.all(Colors.teal.withOpacity(0.12)),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.task_alt, size: 18),
                          label: const Text('Accept'),
                          onPressed: (status == 'on_the_way' || status == 'arrived')
                              ? () async {
                                final result = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(builder: (_) => TakeComplaintStatementScreen(requestId: requestId)),
                                );
                                if (result == true && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted with complaint statement')));
                                }
                              }
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Accept is enabled after the booking moves to Accepted stage (On the way / Arrived).')),
                                  );
                                },
                          style: ButtonStyle(
                            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            side: MaterialStateProperty.all(const BorderSide(color: Colors.orange)),
                            foregroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.pressed)) return Colors.orange;
                              return null;
                            }),
                            backgroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.pressed)) return Colors.orange.withOpacity(0.08);
                              return null;
                            }),
                            overlayColor: MaterialStateProperty.all(Colors.orange.withOpacity(0.12)),
                          ),
                        ),
                        if (status == 'accepted' || status == 'on_the_way' || status == 'arrived')
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Mark as Complete'),
                            onPressed: () async {
                              final res = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(builder: (_) => CreateBillingScreen(requestId: requestId)),
                              );
                              if (res == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment request sent')));
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                      ],
                    );
                  })
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.map, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lat: ${geo.latitude.toStringAsFixed(5)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 24.0, top: 2),
                          child: Row(
                            children: [
                              Text(
                                'Lng: ${geo.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _openMap(address: address, geo: geo),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.directions, size: 18),
                                    SizedBox(width: 4),
                                    Text('Map'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                          .map((url) => GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) {
                                      return Dialog(
                                        insetPadding: const EdgeInsets.all(16),
                                        backgroundColor: Colors.black,
                                        child: InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 4,
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: Image.network(url, fit: BoxFit.contain),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: null,
        );
      },
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
    final List<Widget> separated = [];
    for (int i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i != children.length - 1) {
        separated.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(height: 1),
        ));
      }
    }
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
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
            ...separated,
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
    final textTheme = Theme.of(context).textTheme;
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
                Text(label, style: textTheme.labelMedium?.copyWith(color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text(value, style: textTheme.titleSmall),
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

  Future<void> _update(BuildContext context, String newStatus) async {
    final updates = <String, dynamic>{'status': newStatus};
    if (newStatus == 'accepted') {
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'completed') {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'on_the_way') {
      updates['onTheWayAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'arrived') {
      updates['arrivedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'on_the_way' || newStatus == 'arrived') {
      updates['providerId'] = FirebaseAuth.instance.currentUser?.uid;
      updates['acceptedAt'] = FieldValue.serverTimestamp();
    }
    final reqRef = FirebaseFirestore.instance
        .collection('serviceRequests')
        .doc(requestId);
    // Tracking ID feature removed
    try {
      await reqRef.update(updates);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
      return; // stop if update failed
    }

    try {
      final snap = await reqRef.get();
      final data = snap.data() as Map<String, dynamic>?;
      final customerId = data?['customerId'] as String?;
      final serviceName = (data?['serviceName'] as String?) ?? 'Your booking';
      if (customerId != null && customerId.isNotEmpty) {
        String title, body;
        switch (newStatus) {
          case 'accepted':
            title = 'Booking accepted';
            body = 'Your request for $serviceName was accepted';
            break;
          case 'on_the_way':
            title = 'On the way';
            body = 'Provider is on the way for $serviceName';
            break;
          case 'arrived':
            title = 'Arrived';
            body = 'Provider has arrived for $serviceName';
            break;
          case 'completed':
            title = 'Booking completed';
            final ts = data?['completedAt'];
            if (ts is Timestamp) {
              body = '$serviceName has been marked completed on ' + DateFormat.yMMMd().add_jm().format(ts.toDate());
            } else {
              body = '$serviceName has been marked completed';
            }
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
            onPressed: () => _update(context, 'rejected'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.directions_car, size: 18),
            label: const Text('Start Journey'),
            onPressed: () => _update(context, 'on_the_way'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.place, size: 18),
            label: const Text('Mark Arrived'),
            onPressed: () => _update(context, 'arrived'),
          ),
        ],
      );
    } else if (status == 'accepted' || status == 'on_the_way' || status == 'arrived') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (status == 'on_the_way') ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.place, size: 18),
              label: const Text('Mark Arrived'),
              onPressed: () => _update(context, 'arrived'),
            ),
            const SizedBox(width: 8),
          ],
          if (status == 'on_the_way' || status == 'arrived') ...[
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => TakeComplaintStatementScreen(requestId: requestId)),
                );
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accepted with complaint statement')));
                }
              },
              child: const Text('Accept'),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Mark as Complete'),
            onPressed: () async {
              final res = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => CreateBillingScreen(requestId: requestId)),
              );
              if (res == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment request sent')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      );
    } else {
      return const Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.check_circle, color: Colors.green),
      );
    }
  }
}

class _ActionBar extends StatelessWidget {
  final String requestId;
  final String status;
  const _ActionBar({required this.requestId, required this.status});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: _ActionRow(requestId: requestId, status: status),
      ),
    );
  }
}