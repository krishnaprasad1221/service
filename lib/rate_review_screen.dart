import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RateAndReviewScreen extends StatefulWidget {
  final String requestId;
  final String providerId;
  final String serviceName;
  const RateAndReviewScreen({super.key, required this.requestId, required this.providerId, required this.serviceName});

  @override
  State<RateAndReviewScreen> createState() => _RateAndReviewScreenState();
}

class _RateAndReviewScreenState extends State<RateAndReviewScreen> {
  double _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _loading = true;
  Map<String, dynamic>? _existing;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('serviceReviews')
          .where('requestId', isEqualTo: widget.requestId)
          .where('customerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        _existing = snap.docs.first.data();
        _rating = (_existing!['rating'] as num?)?.toDouble() ?? 0;
        _commentCtrl.text = (_existing!['comment'] as String?) ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }
    setState(() => _submitting = true);

    try {
      // Prevent duplicate by unique composite doc: requestId+customerId
      final docId = '${widget.requestId}_$uid';
      final reviewRef = FirebaseFirestore.instance.collection('serviceReviews').doc(docId);
      await reviewRef.set({
        'requestId': widget.requestId,
        'providerId': widget.providerId,
        'customerId': uid,
        'serviceName': widget.serviceName,
        'rating': _rating,
        'comment': _commentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mark on serviceRequests to indicate reviewed
      await FirebaseFirestore.instance.collection('serviceRequests').doc(widget.requestId).set({
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewBy': uid,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your feedback!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate your service'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(serviceName: widget.serviceName),
                  const SizedBox(height: 16),
                  _StarRating(
                    value: _rating,
                    onChanged: _existing != null ? null : (v) => setState(() => _rating = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentCtrl,
                    enabled: _existing == null,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Share details about your experience (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_existing != null || _submitting) ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: Text(_existing != null ? 'Review submitted' : (_submitting ? 'Submitting...' : 'Submit review')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final String serviceName;
  const _Header({required this.serviceName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.deepPurple, Colors.purple.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.reviews, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How was the service?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(serviceName, style: TextStyle(color: Colors.white.withOpacity(0.95))),
            ]),
          )
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget star(int i) {
      final active = value >= i;
      return GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(i.toDouble()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? Colors.deepPurple.withOpacity(0.1) : Colors.grey.shade100,
            shape: BoxShape.circle,
            boxShadow: [
              if (active)
                BoxShadow(color: Colors.deepPurple.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(active ? Icons.star : Icons.star_border_rounded, size: 36, color: active ? Colors.amber : Colors.grey),
        ),
      );
    }

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [for (int i = 1; i <= 5; i++) star(i)],
      ),
    );
  }
}
