// lib/booking_confirmation_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final String serviceId;
  final String providerId;
  final String serviceName;

  const BookingConfirmationScreen({
    Key? key,
    required this.serviceId,
    required this.providerId,
    required this.serviceName,
  }) : super(key: key);

  @override
  _BookingConfirmationScreenState createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (date == null) return; // User canceled date picker

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _selectedDate = date;
        _selectedTime = time;
      });
    }
  }

  Future<void> _createBookingRequest() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a date and time for the service.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Create a new document in the 'serviceRequests' collection
      await FirebaseFirestore.instance.collection('serviceRequests').add({
        'serviceId': widget.serviceId,
        'serviceName': widget.serviceName,
        'providerId': widget.providerId,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'N/A',
        'bookingTimestamp': FieldValue.serverTimestamp(),
        'scheduledDateTime': Timestamp.fromDate(finalDateTime),
        'status': 'pending', // The initial status of any new request
      });

      Navigator.of(context).pop(); // Go back after booking
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Booking request sent successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Booking'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('You are booking:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(widget.serviceName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: Colors.deepPurple),
              title: const Text('Select Date & Time'),
              subtitle: Text(
                _selectedDate == null
                    ? 'No time selected'
                    : DateFormat.yMMMd()
                        .add_jm()
                        .format(_selectedDate!.add(Duration(
                            hours: _selectedTime!.hour,
                            minutes: _selectedTime!.minute))),
              ),
              onTap: _pickDateTime,
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              onPressed: _isLoading ? null : _createBookingRequest,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              label: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send Booking Request'),
            ),
          ],
        ),
      ),
    );
  }
}