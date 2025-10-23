import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TakeComplaintStatementScreen extends StatefulWidget {
  final String requestId;
  const TakeComplaintStatementScreen({super.key, required this.requestId});

  @override
  State<TakeComplaintStatementScreen> createState() => _TakeComplaintStatementScreenState();
}

class _TakeComplaintStatementScreenState extends State<TakeComplaintStatementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _statementCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _compDate;
  TimeOfDay? _compTime;
  bool _submitting = false;

  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('serviceRequests').doc(widget.requestId).get();
      if (!mounted) return;
      setState(() {
        _data = snap.data();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _statementCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: now, lastDate: DateTime(now.year + 2));
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _pickCompDate() async {
    final now = DateTime.now();
    final initial = _compDate ?? now;
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: now, lastDate: DateTime(now.year + 2));
    if (d != null) setState(() => _compDate = d);
  }

  Future<void> _pickCompTime() async {
    final t = await showTimePicker(context: context, initialTime: _compTime ?? TimeOfDay.now());
    if (t != null) setState(() => _compTime = t);
  }

  DateTime? _composeDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
  }

  DateTime? _composeCompletionDateTime() {
    if (_compDate == null || _compTime == null) return null;
    return DateTime(_compDate!.year, _compDate!.month, _compDate!.day, _compTime!.hour, _compTime!.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final reqRef = FirebaseFirestore.instance.collection('serviceRequests').doc(widget.requestId);
    final Map<String, dynamic> updates = {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'complaintStatement': _statementCtrl.text.trim(),
    };
    final dt = _composeDateTime();
    if (dt != null) {
      updates['scheduledDateTime'] = Timestamp.fromDate(dt);
    }
    final compDt = _composeCompletionDateTime();
    if (compDt != null) {
      updates['expectedCompletionAt'] = Timestamp.fromDate(compDt);
    }

    try {
      await reqRef.update(updates);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
      return;
    }

    try {
      final snap = await reqRef.get();
      final data = snap.data() as Map<String, dynamic>?;
      final customerId = data?['customerId'] as String?;
      final serviceName = (data?['serviceName'] as String?) ?? 'Your booking';
      if (customerId != null && customerId.isNotEmpty) {
        String body = 'Your request for $serviceName was accepted';
        if (compDt != null) {
          body += '. Expected completion: ' + DateFormat.yMMMd().add_jm().format(compDt);
        }
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': customerId,
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'type': 'booking_status',
          'title': 'Booking accepted',
          'body': body,
          'relatedId': widget.requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final serviceName = (_data?['serviceName'] as String?) ?? 'Service Request';
    final scheduledTs = _data?['scheduledDateTime'];
    DateTime? existingSchedule;
    if (scheduledTs is Timestamp) existingSchedule = scheduledTs.toDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Complaint Statement'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  const Icon(Icons.assignment, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(serviceName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (existingSchedule != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Current schedule: ${DateFormat.yMMMd().add_jm().format(existingSchedule)}',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                          ),
                        ),
                    ]),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                      const Text('Take Complaint Statement', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _statementCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Describe the customer\'s problem in detail...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the problem details' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Schedule (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_selectedDate == null
                                  ? 'Pick date'
                                  : DateFormat.yMMMd().format(_selectedDate!)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.schedule),
                              label: Text(_selectedTime == null
                                  ? 'Pick time'
                                  : _selectedTime!.format(context)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Estimated Full Service Completion (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickCompDate,
                              icon: const Icon(Icons.event_available),
                              label: Text(_compDate == null
                                  ? 'Pick completion date'
                                  : DateFormat.yMMMd().format(_compDate!)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickCompTime,
                              icon: const Icon(Icons.access_time),
                              label: Text(_compTime == null
                                  ? 'Pick completion time'
                                  : _compTime!.format(context)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(_submitting ? 'Saving...' : 'Confirm & Accept'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
