import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProviderReviewsScreen extends StatelessWidget {
  const ProviderReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    final query = FirebaseFirestore.instance
        .collection('reviews')
        .where('providerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
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
            return const Center(child: Text('No reviews yet'));
          }

          final docs = snapshot.data!.docs;

          // Compute average rating
          double total = 0;
          int count = 0;
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final r = (data['rating'] as num?)?.toDouble();
            if (r != null) {
              total += r;
              count++;
            }
          }
          final double avg = count == 0 ? 0.0 : total / count;

          return Column(
            children: [
              _SummaryHeader(avgRating: avg, totalReviews: docs.length),
              const Divider(height: 0),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _ReviewTile(data: data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final double avgRating;
  final int totalReviews;
  const _SummaryHeader({required this.avgRating, required this.totalReviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.deepPurple.withOpacity(0.05),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Text(avgRating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (int i = 1; i <= 5; i++)
                    Icon(
                      i <= avgRating.round() ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('$totalReviews review(s)', style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReviewTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = (data['comment'] as String?) ?? '';
    final createdAtTs = data['createdAt'];
    DateTime? createdAt;
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();
    final createdAtStr = createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '';
    final customerName = (data['customerName'] as String?) ?? 'Customer';

    return ListTile(
      title: Row(
        children: [
          for (int i = 1; i <= 5; i++)
            Icon(
              i <= rating.round() ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 18,
            ),
          const SizedBox(width: 8),
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(comment),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Expanded(child: Text(customerName, overflow: TextOverflow.ellipsis)),
              if (createdAtStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text(createdAtStr),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
