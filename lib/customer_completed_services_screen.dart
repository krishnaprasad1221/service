import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerCompletedServicesScreen extends StatelessWidget {
  const CustomerCompletedServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final query = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where('customerId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Services'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No completed services yet'));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final serviceName = (data['serviceName'] as String?) ?? 'Service';
              final providerId = (data['providerId'] as String?) ?? '';
              final providerName = (data['providerName'] as String?) ?? 'Provider';
              final completedAtTs = data['completedAt'];
              DateTime? completedAt;
              if (completedAtTs is Timestamp) completedAt = completedAtTs.toDate();
              final completedStr = completedAt != null
                  ? DateFormat.yMMMd().add_jm().format(completedAt!)
                  : '';

              return ListTile(
                title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('By: $providerName'),
                    if (completedStr.isNotEmpty)
                      Text('Completed: $completedStr'),
                  ],
                ),
                trailing: _ReviewAction(
                  bookingId: doc.id,
                  providerId: providerId,
                  serviceName: serviceName,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReviewAction extends StatelessWidget {
  final String bookingId;
  final String providerId;
  final String serviceName;
  const _ReviewAction({required this.bookingId, required this.providerId, required this.serviceName});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final reviewQuery = FirebaseFirestore.instance
        .collection('reviews')
        .where('bookingId', isEqualTo: bookingId)
        .where('customerId', isEqualTo: uid)
        .limit(1);

    return StreamBuilder<QuerySnapshot>(
      stream: reviewQuery.snapshots(),
      builder: (context, snapshot) {
        final exists = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        return ElevatedButton(
          onPressed: () async {
            if (exists) {
              _showExistingReview(context, snapshot.data!.docs.first.data() as Map<String, dynamic>);
            } else {
              await _openCreateReviewDialog(context, bookingId: bookingId, providerId: providerId, serviceName: serviceName);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: exists ? Colors.grey : Colors.deepPurple, foregroundColor: Colors.white),
          child: Text(exists ? 'View Review' : 'Add Review'),
        );
      },
    );
  }

  void _showExistingReview(BuildContext context, Map<String, dynamic> data) {
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = (data['comment'] as String?) ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Your Review for "$serviceName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StaticStars(rating: rating),
            const SizedBox(height: 8),
            if (comment.isNotEmpty) Text(comment),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _openCreateReviewDialog(BuildContext context, {required String bookingId, required String providerId, required String serviceName}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final customerName = (userDoc.data()?['username'] as String?) ?? 'Customer';

    double rating = 5.0;
    final controller = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Review "$serviceName"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InteractiveStars(
                initial: rating,
                onChanged: (v) => setState(() => rating = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('reviews').add({
                  'bookingId': bookingId,
                  'providerId': providerId,
                  'customerId': uid,
                  'customerName': customerName,
                  'serviceName': serviceName,
                  'rating': rating,
                  'comment': controller.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if ((submitted ?? false) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted'), backgroundColor: Colors.green),
      );
    }
  }
}

class _StaticStars extends StatelessWidget {
  final double rating;
  const _StaticStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= rating.round() ? Icons.star : Icons.star_border,
            size: 20,
            color: Colors.amber,
          ),
        const SizedBox(width: 8),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InteractiveStars extends StatelessWidget {
  final double initial;
  final ValueChanged<double> onChanged;
  const _InteractiveStars({required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    double current = initial;
    return StatefulBuilder(
      builder: (context, setState) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starIndex = index + 1;
          return IconButton(
            icon: Icon(
              current >= starIndex ? Icons.star : Icons.star_border,
              color: Colors.amber,
            ),
            onPressed: () {
              setState(() => current = starIndex.toDouble());
              onChanged(current);
            },
          );
        }),
      ),
    );
  }
}
