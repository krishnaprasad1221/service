import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateBillingScreen extends StatefulWidget {
  final String requestId;
  const CreateBillingScreen({super.key, required this.requestId});

  @override
  State<CreateBillingScreen> createState() => _CreateBillingScreenState();
}

class _CreateBillingScreenState extends State<CreateBillingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceChargeCtrl = TextEditingController();
  final List<_PartRow> _parts = [];
  bool _sending = false;
  Map<String, dynamic>? _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('serviceRequests').doc(widget.requestId).get();
      setState(() {
        _request = snap.data();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _serviceChargeCtrl.dispose();
    super.dispose();
  }

  double _parseMoney(String? s) {
    final v = double.tryParse(s?.trim() ?? '');
    return v == null || v.isNaN ? 0.0 : v;
  }

  double get _partsTotal => _parts.fold(0.0, (sum, e) => sum + _parseMoney(e.priceCtrl.text));
  double get _serviceCharge => _parseMoney(_serviceChargeCtrl.text);
  double get _grandTotal => _partsTotal + _serviceCharge;

  Future<void> _sendPaymentRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final parts = _parts
        .where((p) => p.nameCtrl.text.trim().isNotEmpty)
        .map((p) => {
              'name': p.nameCtrl.text.trim(),
              'price': _parseMoney(p.priceCtrl.text),
            })
        .toList();

    final reqRef = FirebaseFirestore.instance.collection('serviceRequests').doc(widget.requestId);
    try {
      await reqRef.update({
        'parts': parts,
        'serviceCharge': _serviceCharge,
        'finalAmount': _grandTotal,
        'status': 'payment_requested',
        'paymentRequestedAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send payment request: $e')));
      }
      return;
    }

    try {
      final snap = await reqRef.get();
      final data = snap.data() as Map<String, dynamic>?;
      final customerId = data?['customerId'] as String?;
      final serviceName = (data?['serviceName'] as String?) ?? 'Your booking';
      if (customerId != null && customerId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': customerId,
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'type': 'booking_status',
          'title': 'Payment requested',
          'body': 'Payment requested for $serviceName. Please review and pay.',
          'relatedId': widget.requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _sending = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final serviceName = (_request?['serviceName'] as String?) ?? 'Service Request';
    final customerName = (_request?['customerName'] as String?) ?? 'Customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bill'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
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
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(serviceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Customer: $customerName', style: TextStyle(color: Colors.white.withOpacity(0.95))),
                    ]),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bill form
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Parts/Items', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ..._parts.map((row) => _PartRowWidget(row: row, onRemove: () => setState(() => _parts.remove(row)))).toList(),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _parts.add(_PartRow())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                      const Divider(height: 32),
                      const Text('Service Charge', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _serviceChargeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'Enter service charge', prefixText: '₹ ', border: OutlineInputBorder()),
                        validator: (v) => (double.tryParse(v?.trim() ?? '') == null) ? 'Enter a valid amount' : null,
                      ),
                      const SizedBox(height: 16),
                      _Totals(partsTotal: _partsTotal, serviceCharge: _serviceCharge, grandTotal: _grandTotal),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _sendPaymentRequest,
              icon: const Icon(Icons.request_page),
              label: Text(_sending ? 'Sending...' : 'Send Payment Request'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final double partsTotal;
  final double serviceCharge;
  final double grandTotal;
  const _Totals({required this.partsTotal, required this.serviceCharge, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    Text _row(String label, double value, {bool bold = false}) => Text(
          '$label: ₹ ${value.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Parts Total', partsTotal),
        const SizedBox(height: 6),
        _row('Service Charge', serviceCharge),
        const Divider(height: 22),
        _row('Grand Total', grandTotal, bold: true),
      ],
    );
  }
}

class _PartRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
}

class _PartRowWidget extends StatelessWidget {
  final _PartRow row;
  final VoidCallback onRemove;
  const _PartRowWidget({super.key, required this.row, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.nameCtrl,
              decoration: const InputDecoration(hintText: 'Part/Item name', border: OutlineInputBorder()),
              validator: (v) {
                if ((v?.trim().isEmpty ?? true)) return 'Enter item';
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: row.priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Price', border: OutlineInputBorder()),
              validator: (v) => (double.tryParse(v?.trim() ?? '') == null) ? 'Invalid' : null,
            ),
          ),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline))
        ],
      ),
    );
  }
}
