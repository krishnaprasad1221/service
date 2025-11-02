import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'booking_detail_screen.dart';
import 'rate_review_screen.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() => _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState extends State<CustomerNotificationsScreen> {
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final baseQuery = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            tooltip: _showUnreadOnly ? 'Show all' : 'Show unread only',
            icon: Icon(_showUnreadOnly ? Icons.mark_email_read : Icons.mark_email_unread),
            onPressed: () => setState(() => _showUnreadOnly = !_showUnreadOnly),
          ),
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              final snap = await baseQuery.limit(100).get();
              final batch = FirebaseFirestore.instance.batch();
              for (final d in snap.docs) {
                final data = d.data() as Map<String, dynamic>;
                if ((data['isRead'] as bool?) != true) {
                  batch.update(d.reference, {'isRead': true});
                }
              }
              await batch.commit();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: baseQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          final allDocs = snapshot.data!.docs;
          final docs = _showUnreadOnly
              ? allDocs.where((d) => ((d.data() as Map<String, dynamic>)['isRead'] as bool?) != true).toList()
              : allDocs;

          if (docs.isEmpty) {
            return const Center(child: Text('No unread notifications'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final title = (data['title'] as String?) ?? 'Notification';
              final body = (data['body'] as String?) ?? '';
              final isRead = (data['isRead'] as bool?) ?? false;
              final String type = (data['type'] as String?) ?? 'general';
              final String? relatedId = data['relatedId'] as String?;
              // trackingId removed from notifications UI
              final ts = data['createdAt'];
              final String? status = (data['status'] as String?);
              DateTime? dt;
              if (ts is Timestamp) dt = ts.toDate();
              final tsStr = dt != null ? DateFormat.yMMMd().add_jm().format(dt) : '';

              IconData leadingIcon;
              switch (type) {
                case 'booking_status':
                  leadingIcon = Icons.event_available; // accepted/completed/updates
                  break;
                case 'payment_request':
                  leadingIcon = Icons.request_page; // provider requested payment
                  break;
                case 'rating_request':
                  leadingIcon = Icons.star_rate; // rate and review request
                  break;
                case 'system':
                  leadingIcon = Icons.info_outline;
                  break;
                default:
                  leadingIcon = isRead ? Icons.notifications_none : Icons.notifications_active;
              }

              return Dismissible(
                key: ValueKey(doc.id),
                background: Container(
                  color: Colors.green,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.mark_email_read, color: Colors.white),
                ),
                secondaryBackground: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    await doc.reference.update({'isRead': true});
                    return false; // keep in list, just mark read
                  } else {
                    await doc.reference.delete();
                    return true; // remove from list
                  }
                },
                child: ListTile(
                  leading: Icon(
                    leadingIcon,
                    color: isRead ? Colors.grey : Colors.deepPurple,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)) ),
                      if (status != null && status.isNotEmpty) _StatusChip(status: status),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (body.isNotEmpty) Text(body),
                      if (tsStr.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(tsStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: isRead ? 'Mark as unread' : 'Mark as read',
                    icon: Icon(isRead ? Icons.mark_email_unread : Icons.mark_email_read),
                    onPressed: () async {
                      await doc.reference.update({'isRead': !isRead});
                    },
                  ),
                  onTap: () async {
                    if (!isRead) {
                      await doc.reference.update({'isRead': true});
                    }
                    
                    // Handle rating_request notification tap
                    if (type == 'rating_request' && relatedId != null) {
                      final providerId = data['providerId'] as String?;
                      final serviceName = (data['serviceName'] as String?) ?? 'Service';
                      if (providerId != null && context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RateAndReviewScreen(
                              requestId: relatedId,
                              providerId: providerId,
                              serviceName: serviceName,
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    
                    // Navigation to booking details intentionally disabled per requirements
                    return;
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _colorFor(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    final label = status.isNotEmpty
        ? status[0].toUpperCase() + status.substring(1)
        : 'Status';
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
