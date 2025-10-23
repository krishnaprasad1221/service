// lib/on_time_bookings_screen.dart

import 'package:flutter/material.dart';
import 'create_billing_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'booking_detail_screen.dart';

class OnTimeBookingsScreen extends StatelessWidget {
  const OnTimeBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('On Time Service Requests'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .where('providerId', isEqualTo: user.uid)
            .where('onTime', isEqualTo: true)
            .orderBy('scheduledDateTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No "On Time" requests found.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildBookingCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Future<void> _updateRequestStatus(BuildContext context, String docId, String newStatus) async {
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
      await docRef.update(updates);

      // Notify customer
      final snap = await docRef.get();
      final data = snap.data() as Map<String, dynamic>?;
      if (data != null) {
        final String? customerId = data['customerId'] as String?;
        final String serviceName = (data['serviceName'] as String?) ?? 'Your booking';
        if (customerId != null && customerId.isNotEmpty) {
          String title;
          String body;
          if (newStatus == 'accepted') {
            title = 'Booking accepted';
            body = 'Your request for $serviceName was accepted';
          } else if (newStatus == 'completed') {
            title = 'Booking completed';
            body = '$serviceName has been marked completed';
          } else if (newStatus == 'rejected') {
            title = 'Booking rejected';
            body = 'Your request for $serviceName was rejected';
          } else {
            title = 'Booking update';
            body = 'Status changed to $newStatus for $serviceName';
          }
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': customerId,
            'createdBy': FirebaseAuth.instance.currentUser?.uid,
            'type': 'booking_status',
            'title': title,
            'body': body,
            'relatedId': docId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Widget _buildBookingCard(
      BuildContext context, String docId, Map<String, dynamic> data) {
    final scheduledDate = (data['scheduledDateTime'] as Timestamp).toDate();
    final scheduledDateStr = DateFormat.yMMMd().format(scheduledDate);
    final scheduledTimeStr = DateFormat.jm().format(scheduledDate);

    final String status = (data['status'] as String?) ?? 'pending';

    final String? estimatedDuration = (data['estimatedDurationDays'] != null) 
        ? "${data['estimatedDurationDays']} day(s)" 
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailScreen(requestId: docId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      data['serviceName'] ?? 'No Service Name',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('On Time'),
                    backgroundColor: Colors.deepPurple.withOpacity(0.12),
                    labelStyle: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w600),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data['customerName'] ?? 'Customer',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('$scheduledDateStr at $scheduledTimeStr'),
                ],
              ),
              if (estimatedDuration != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Estimated: $estimatedDuration'),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _buildActionButtons(context, docId, status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String docId, String status) {
    if (status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => _updateRequestStatus(context, docId, 'rejected'),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _updateRequestStatus(context, docId, 'accepted'),
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
          onPressed: () async {
            final res = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => CreateBillingScreen(requestId: docId)),
            );
            if (res == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment request sent')),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      );
    } else {
      return const Align(
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
      );
    }
  }
}
