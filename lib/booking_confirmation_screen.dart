// lib/booking_confirmation_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

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

  // Address / location inputs
  final _addressLineCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  GeoPoint? _geoSnapshot;

  // Contact & Access inputs
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _accessNotesCtrl = TextEditingController();

  // Job details
  final _instructionsCtrl = TextEditingController();
  bool _uploading = false;
  final List<String> _attachmentUrls = [];
  int _estimatedDays = 1;
  bool _onTime = false;

  @override
  void dispose() {
    _addressLineCtrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _landmarkCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _accessNotesCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _uploading = true);

      final Uint8List bytes = await file.readAsBytes();
      final String fileName =
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('service_images/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      setState(() {
        _attachmentUrls.add(url);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        return; // Cannot request permissions
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _geoSnapshot = GeoPoint(pos.latitude, pos.longitude);
      });

      // Best-effort reverse geocode
      try {
        final placemarks =
            await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          _addressLineCtrl.text = [
            p.street,
            p.subLocality,
          ].where((e) => (e ?? '').isNotEmpty).join(', ');
          _cityCtrl.text = p.locality ?? p.subAdministrativeArea ?? '';
          _pincodeCtrl.text = p.postalCode ?? '';
          _landmarkCtrl.text = p.name ?? '';
          if (mounted) setState(() {});
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location captured'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (date == null) return;

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
          content: Text('Please select a date and time for the service.'),
        ),
      );
      return;
    }
    if (_addressLineCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your address')),
      );
      return;
    }
    final phone = _contactPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a contact phone number')),
      );
      return;
    }
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length < 10 || phoneDigits.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number (10-15 digits)'),
        ),
      );
      return;
    }
    final pin = _pincodeCtrl.text.trim();
    if (pin.isNotEmpty && pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-digit pincode')),
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

      final reqRef =
          await FirebaseFirestore.instance.collection('serviceRequests').add({
        'serviceId': widget.serviceId,
        'serviceName': widget.serviceName,
        'providerId': widget.providerId,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'N/A',
        'bookingTimestamp': FieldValue.serverTimestamp(),
        'scheduledDateTime': Timestamp.fromDate(finalDateTime),
        'status': 'pending',

        // Address snapshot
        'addressSnapshot': {
          'addressLine': _addressLineCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'pincode': _pincodeCtrl.text.trim(),
          'landmark': _landmarkCtrl.text.trim(),
        },

        // Geo snapshot (optional)
        if (_geoSnapshot != null) 'geoSnapshot': _geoSnapshot,

        // Contact & Access
        'contact': {
          'name': _contactNameCtrl.text.trim(),
          'phone': _contactPhoneCtrl.text.trim(),
        },
        'accessNotes': _accessNotesCtrl.text.trim(),

        // Job details
        'instructions': _instructionsCtrl.text.trim(),
        if (_attachmentUrls.isNotEmpty) 'attachments': _attachmentUrls,
        'estimatedDurationDays': _estimatedDays,
        'onTime': _onTime,
      });

      // Provider notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.providerId,
        'createdBy': user.uid,
        'type': 'booking_created',
        'title': 'New booking request',
        'body':
            '${user.displayName ?? 'A customer'} requested ${widget.serviceName}',
        'relatedId': reqRef.id,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
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
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Service Location
              Text('Service Location',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _addressLineCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address Line',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _pincodeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _landmarkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Landmark (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use my current location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_geoSnapshot != null)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Divider(height: 32),

              // Contact & Access
              Text('Contact & Access',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contactNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _contactPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accessNotesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Access Notes (gate code, floor, elevator, etc.)',
                  border: OutlineInputBorder(),
                ),
              ),
              const Divider(height: 32),

              // Job Details
              Text('Job Details',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _instructionsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Instructions (optional)',
                  hintText: 'Describe the job, special requests, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading || _uploading
                        ? null
                        : _pickAndUploadImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Add Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_uploading)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_attachmentUrls.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachmentUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _attachmentUrls[i],
                        height: 72,
                        width: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Estimated duration (days) stepper
              Text('Estimated Duration (days)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  // On Time toggle button (left of the duration stepper)
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _onTime = !_onTime),
                    style: _onTime
                        ? OutlinedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          )
                        : null,
                    icon: const Icon(Icons.access_time),
                    label: const Text('On Time'),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _isLoading || _estimatedDays <= 1
                        ? null
                        : () => setState(() => _estimatedDays -= 1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_estimatedDays day${_estimatedDays > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _estimatedDays += 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Summary + Date Picker
              Text('You are booking:',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                widget.serviceName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.calendar_today, color: Colors.deepPurple),
                title: const Text('Select Date & Time'),
                subtitle: Text(
                  _selectedDate == null || _selectedTime == null
                      ? 'No time selected'
                      : DateFormat.yMMMd().add_jm().format(
                            DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                              _selectedTime!.hour,
                              _selectedTime!.minute,
                            ),
                          ),
                ),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 16),

              // Submit
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                onPressed: _isLoading ? null : _createBookingRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send Booking Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}