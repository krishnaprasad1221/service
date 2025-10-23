import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'widgets/service_timeline_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'booking_detail_screen.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  /// Helper widget to display a colored status chip based on the booking status.
  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String text = status[0].toUpperCase() + status.substring(1); // Capitalize

    switch (status) {
      case 'accepted':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.check_circle;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.hourglass_top_outlined;
        break;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Requests')),
        body: const Center(child: Text('Please log in to see your requests.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .where('customerId', isEqualTo: user.uid)
            .orderBy('bookingTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(context);
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'You have not made any service requests yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? scheduledTs = data['scheduledDateTime'] as Timestamp?;
              final DateTime? scheduledDate = scheduledTs?.toDate();
              final String scheduledText = scheduledDate != null
                  ? DateFormat.yMMMd().add_jm().format(scheduledDate)
                  : 'Not scheduled yet';

              final String status = (data['status'] as String?) ?? 'pending';
              // trackingId removed from UI

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    (data['serviceName'] ?? 'Service Request').toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('Scheduled for: $scheduledText'),
                  trailing: _buildStatusChip(status),
                  children: [
                    const SizedBox(height: 8),
                    // Service details can be added here if needed
                    Text('Status: ${status[0].toUpperCase() + status.substring(1)}'),
                    if (scheduledDate != null)
                      Text('Scheduled: ${DateFormat.yMMMd().add_jm().format(scheduledDate)}'),
                    const SizedBox(height: 8),
                    Builder(builder: (context) {
                      final Timestamp? bookedTs = data['bookingTimestamp'] as Timestamp?;
                      final Timestamp? acceptedTs = data['acceptedAt'] as Timestamp?;
                      final Timestamp? onTheWayTs = data['onTheWayAt'] as Timestamp?;
                      final Timestamp? arrivedTs = data['arrivedAt'] as Timestamp?;
                      final Timestamp? completedTs = data['completedAt'] as Timestamp?;
                      final Timestamp? paymentReqTs = data['paymentRequestedAt'] as Timestamp?;
                      final Timestamp? paidTs = data['paidAt'] as Timestamp?;
                      final Timestamp? expectedCompletionTs = data['expectedCompletionAt'] as Timestamp?;
                      return ServiceTimelineWidget(
                        status: status,
                        bookedAt: bookedTs?.toDate(),
                        acceptedAt: acceptedTs?.toDate(),
                        onTheWayAt: onTheWayTs?.toDate(),
                        arrivedAt: arrivedTs?.toDate(),
                        completedAt: completedTs?.toDate(),
                        paymentRequestedAt: paymentReqTs?.toDate(),
                        paidAt: paidTs?.toDate(),
                        onTime: (data['onTime'] == true),
                        estimatedDurationDays: (data['estimatedDurationDays'] as int?),
                        expectedCompletionAt: expectedCompletionTs?.toDate(),
                      );
                    }),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.contact_phone, size: 18),
                          label: const Text('Contact Provider'),
                          onPressed: () async {
                            final String? providerId = data['providerId'] as String?;
                            if (providerId == null || providerId.isEmpty) return;
                            try {
                              final snap = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
                              final m = snap.data() as Map<String, dynamic>?;
                              final name = (m?['username'] as String?) ?? 'Provider';
                              final phone = m?['phone'] as String?;
                              final email = m?['email'] as String?;
                              if (!context.mounted) return;
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                                builder: (_) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (phone != null && phone.isNotEmpty)
                                          ListTile(
                                            leading: const Icon(Icons.call),
                                            title: Text(phone),
                                            onTap: () async {
                                              final uri = Uri.parse('tel:$phone');
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                          ),
                                        if (email != null && email.isNotEmpty)
                                          ListTile(
                                            leading: const Icon(Icons.email_outlined),
                                            title: Text(email),
                                            onTap: () async {
                                              final uri = Uri.parse('mailto:$email');
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            } catch (_) {}
                          },
                        ),
                        const SizedBox(width: 8),
                        Builder(builder: (context) {
                          final Timestamp? bookedTs = data['bookingTimestamp'] as Timestamp?;
                          final DateTime? bookedAt = bookedTs?.toDate();
                          final String? providerId = data['providerId'] as String?;
                          final now = DateTime.now();
                          final within2h = bookedAt != null && now.difference(bookedAt).inMinutes <= 120;
                          // Allow cancel only while request is still pending (disable after Start Journey/on_the_way and beyond)
                          final canCancel = within2h && (status == 'pending') && (providerId != null && providerId.isNotEmpty);
                          if (!canCancel) return const SizedBox.shrink();
                          return OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_schedule_send, size: 18, color: Colors.red),
                            label: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Cancel booking?'),
                                  content: const Text('You can cancel within 2 hours of booking. This will notify the provider.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              try {
                                await FirebaseFirestore.instance
                                    .collection('serviceRequests')
                                    .doc(doc.id)
                                    .update({
                                  'status': 'cancelled',
                                  'cancelledAt': FieldValue.serverTimestamp(),
                                });
                                // Notify provider
                                await FirebaseFirestore.instance.collection('notifications').add({
                                  'userId': providerId,
                                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                                  'type': 'booking_status',
                                  'title': 'Booking cancelled',
                                  'body': 'A customer cancelled ${data['serviceName'] ?? 'a booking'}',
                                  'relatedId': doc.id,
                                  'isRead': false,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Booking cancelled')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to cancel: $e')),
                                  );
                                }
                              }
                            },
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This usually means a database index is missing. Please check your debug console for a link to create it.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTimeline extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ServiceTimeline({required this.data});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = (data['status'] as String?) ?? 'pending';
    final Timestamp? requestedTs = data['bookingTimestamp'] as Timestamp?;
    final Timestamp? acceptedTs = data['acceptedAt'] as Timestamp?;
    final Timestamp? scheduledTs = data['scheduledDateTime'] as Timestamp?;
    final Timestamp? completedTs = data['completedAt'] as Timestamp?;

    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Requested',
        dt: requestedTs?.toDate(),
        icon: Icons.schedule,
        color: Colors.blueGrey,
        isActive: requestedTs != null,
      ),
      if (status == 'rejected')
        _TimelineStep(
          label: 'Rejected',
          dt: acceptedTs?.toDate() ?? requestedTs?.toDate(),
          icon: Icons.cancel_outlined,
          color: Colors.red,
          isActive: true,
        )
      else ...[
        _TimelineStep(
          label: 'Accepted',
          dt: acceptedTs?.toDate(),
          icon: Icons.task_alt,
          color: Colors.orange,
          isActive: acceptedTs != null,
        ),
        _TimelineStep(
          label: 'Scheduled',
          dt: scheduledTs?.toDate(),
          icon: Icons.event,
          color: Colors.indigo,
          isActive: scheduledTs != null,
        ),
        _TimelineStep(
          label: 'Completed',
          dt: completedTs?.toDate(),
          icon: Icons.check_circle,
          color: Colors.green,
          isActive: status == 'completed' && completedTs != null,
        ),
      ],
    ];

    // Trim trailing inactive steps for cleaner look
    final trimmed = _trimTrailingInactive(steps);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline rail
        Column(
          children: List.generate(trimmed.length * 2 - 1, (i) {
            if (i.isEven) {
              final idx = i ~/ 2;
              final step = trimmed[idx];
              return _Dot(icon: step.icon, color: step.isActive ? step.color : Colors.grey.shade400);
            } else {
              return Container(width: 2, height: 22, color: Colors.grey.shade300);
            }
          }),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < trimmed.length; i++) ...[
                _StepRow(step: trimmed[i]),
                if (i < trimmed.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<_TimelineStep> _trimTrailingInactive(List<_TimelineStep> steps) {
    int end = steps.length - 1;
    while (end > 0 && !steps[end].isActive) {
      end--;
    }
    return steps.sublist(0, end + 1);
  }
}

class _TimelineStep {
  final String label;
  final DateTime? dt;
  final IconData icon;
  final Color color;
  final bool isActive;
  _TimelineStep({required this.label, required this.dt, required this.icon, required this.color, required this.isActive});
}

class _Dot extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Dot({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

class _StepRow extends StatelessWidget {
  final _TimelineStep step;
  const _StepRow({required this.step});
  @override
  Widget build(BuildContext context) {
    final String timeStr = step.dt != null
        ? DateFormat.yMMMd().add_jm().format(step.dt!)
        : 'Pending';
    final TextStyle labelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: step.isActive ? Colors.grey[900] : Colors.grey[600],
    );
    final TextStyle tsStyle = TextStyle(
      color: step.isActive ? Colors.grey[800] : Colors.grey[500],
      fontSize: 13,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step.label, style: labelStyle),
        const SizedBox(height: 2),
        Text(timeStr, style: tsStyle),
      ],
    );
  }
}

