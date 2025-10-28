// lib/payment_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:serviceprovider/rate_review_screen.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.green,
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in to view payments'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('serviceRequests')
                  .where('customerId', isEqualTo: uid)
                  .where('status', whereIn: ['payment_requested', 'paid'])
                  .orderBy('paymentRequestedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No payment requests yet.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final serviceName = (data['serviceName'] as String?) ?? 'Service';
                    final providerName = (data['providerName'] as String?) ?? 'Provider';
                    final parts = (data['parts'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
                    final serviceCharge = (data['serviceCharge'] as num?)?.toDouble() ?? 0.0;
                    final finalAmount = (data['finalAmount'] as num?)?.toDouble() ?? (serviceCharge + parts.fold<double>(0.0, (s, p) => s + ((p['price'] as num?)?.toDouble() ?? 0.0)));
                    final status = (data['status'] as String?) ?? 'pending';
                    final reqAt = (data['paymentRequestedAt'] as Timestamp?);
                    final paidAt = (data['paidAt'] as Timestamp?);

                    return _BillCard(
                      requestId: doc.id,
                      serviceName: serviceName,
                      providerName: providerName,
                      parts: parts,
                      serviceCharge: serviceCharge,
                      finalAmount: finalAmount,
                      status: status,
                      requestedAt: reqAt?.toDate(),
                      paidAt: paidAt?.toDate(),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final String requestId;
  final String serviceName;
  final String providerName;
  final List<Map<String, dynamic>> parts;
  final double serviceCharge;
  final double finalAmount;
  final String status;
  final DateTime? requestedAt;
  final DateTime? paidAt;

  const _BillCard({
    required this.requestId,
    required this.serviceName,
    required this.providerName,
    required this.parts,
    required this.serviceCharge,
    required this.finalAmount,
    required this.status,
    required this.requestedAt,
    required this.paidAt,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'paid';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('By $providerName', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            if (parts.isNotEmpty) ...[
              const Text('Parts/Items', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...parts.map((p) {
                final name = (p['name'] as String?) ?? 'Item';
                final price = (p['price'] as num?)?.toDouble() ?? 0.0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name),
                    Text('₹ ${price.toStringAsFixed(2)}'),
                  ],
                );
              }),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service Charge'),
                Text('₹ ${serviceCharge.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('₹ ${finalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            if (requestedAt != null)
              Text('Requested on ${DateFormat.yMMMd().add_jm().format(requestedAt!)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            if (isPaid && paidAt != null)
              Text('Paid on ${DateFormat.yMMMd().add_jm().format(paidAt!)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 12),
            if (!isPaid)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _onPayNowPressed(context),
                  icon: const Icon(Icons.payment),
                  label: const Text('Pay Now'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPayNowPressed(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                  title: const Text('Online Payment'),
                  subtitle: const Text('Pay securely using Razorpay'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openRazorpay(context);
                  },
                ),
                const Divider(height: 10),
                ListTile(
                  leading: const Icon(Icons.money_rounded, color: Colors.orange),
                  title: const Text('Cash'),
                  subtitle: const Text('Pay cash directly to the service provider'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmCashPayment(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCashPayment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          title: const Text('Confirm Cash Payment'),
          content: Text('Confirm that you have paid ₹ ${finalAmount.toStringAsFixed(2)} in cash to $providerName for $serviceName.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('Confirm')),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _markAsPaidAndNotify(context, paymentMethod: 'cash');
    }
  }

  Future<void> _openRazorpay(BuildContext context) async {
    final razorpay = Razorpay();
    void handleSuccess(PaymentSuccessResponse response) async {
      await _markAsPaidAndNotify(context, paymentMethod: 'online');
      razorpay.clear();
    }

    void handleError(PaymentFailureResponse response) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${response.message ?? 'Unknown error'}')),
        );
      }
      razorpay.clear();
    }

    void handleExternalWallet(ExternalWalletResponse response) {
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handleSuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handleError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWallet);

    final amountPaise = (finalAmount * 100).round();
    final user = FirebaseAuth.instance.currentUser;

    final options = {
      'key': 'rzp_test_RWRMUwaEf4eLLC',
      'amount': amountPaise,
      'currency': 'INR',
      'name': serviceName,
      'description': 'Payment for $serviceName',
      'notes': {
        'requestId': requestId,
        'providerName': providerName,
      },
      'prefill': {
        'email': user?.email ?? '',
        'contact': user?.phoneNumber ?? '',
        'name': 'Customer',
      },
      'theme': {
        'color': '#00A651',
      }
    };

    try {
      razorpay.open(options);
    } catch (e) {
      razorpay.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to start payment: $e')));
      }
    }
  }

  Future<void> _markAsPaidAndNotify(BuildContext context, {String? paymentMethod}) async {
    final reqRef = FirebaseFirestore.instance.collection('serviceRequests').doc(requestId);
    try {
      final update = {
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      };
      if (paymentMethod != null) {
        // Record the method used without changing existing status flow
        (update as Map<String, dynamic>)['paymentMethod'] = paymentMethod;
      }
      await reqRef.update(update);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to mark paid: $e')));
      }
      return;
    }

    try {
      final snap = await reqRef.get();
      final data = snap.data() as Map<String, dynamic>?;
      final providerId = data?['providerId'] as String?;
      final sName = (data?['serviceName'] as String?) ?? 'Your booking';
      if (providerId != null && providerId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': providerId,
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'type': 'booking_status',
          'title': 'Payment received',
          'body': paymentMethod == 'cash' ? 'Cash payment received for $sName' : 'Payment received for $sName',
          'relatedId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Navigate to rating & review immediately after a successful payment
      if (context.mounted && providerId != null && providerId.isNotEmpty) {
        // Await the review screen; it will handle duplicate prevention itself
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RateAndReviewScreen(
              requestId: requestId,
              providerId: providerId,
              serviceName: sName,
            ),
          ),
        );
      }
    } catch (_) {}

    if (context.mounted) {
      final msg = paymentMethod == 'cash' ? 'Cash payment confirmed' : 'Payment successful';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color() {
    switch (status) {
      case 'payment_requested':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _label() {
    switch (status) {
      case 'payment_requested':
        return 'Payment Requested';
      case 'paid':
        return 'Paid';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color()),
      ),
      child: Text(_label(), style: TextStyle(color: _color(), fontWeight: FontWeight.w600)),
    );
  }
}