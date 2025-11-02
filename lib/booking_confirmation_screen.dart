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
import 'package:intl/intl.dart';
import 'ml_models/arrival_prediction_models.dart';

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
  double? _predictedEta; // Store the predicted ETA in minutes

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
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _geoPoint = GeoPoint(position.latitude, position.longitude);
      });

      // Best-effort reverse geocode
      try {
        final placemarks =
            await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
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

  // Get the next available time slot that minimizes wait time
  Future<void> _suggestOptimalTime() async {
    if (_selectedService == null) return;
    
    final now = DateTime.now();
    final optimalTime = _predictionModel.getOptimalBookingTime(
      now,
      _selectedService.id,
      lookaheadHours: 24,
    );
    
    setState(() {
      _suggestedTime = TimeOfDay.fromDateTime(optimalTime);
    });
  }
  
  // Track training data for this session
  List<List<double>> _trainingData = [];
  TimeOfDay? _suggestedTime;
  GeoPoint? _geoPoint;
  
  // Track which algorithm is being used
  String _currentAlgorithm = 'Decision Tree';
  
  // Algorithm information
  final Map<String, Map<String, dynamic>> _algorithms = {
    'Decision Tree': {
      'icon': Icons.account_tree,
      'color': Colors.blue,
      'description': 'Uses clear, rule-based conditions to estimate arrival time',
      'features': [
        'Time of day',
        'Day of week',
        'Service type',
        'Distance',
        'Traffic conditions'
      ]
    },
    'K-Nearest Neighbors': {
      'icon': Icons.people_alt,
      'color': Colors.blue,
      'description': 'Finds similar past bookings to predict arrival time',
      'features': [
        'Historical booking patterns',
        'Similar time slots',
        'Service type matching',
        'Distance similarity',
        'Traffic conditions'
      ]
    },
    'Naive Bayes': {
      'icon': Icons.analytics,
      'color': Colors.purple,
      'description': 'Uses probability to predict arrival time based on feature likelihoods',
      'features': [
        'Time of day probability',
        'Day type analysis',
        'Peak hour detection',
        'Traffic level assessment',
        'Distance category'
      ]
    },
  };
  
  // Instance of the prediction model
  final _predictionModel = ArrivalPredictionModels();
  
  // Initialize with default values
  int _trafficLevel = 3; // Default traffic level (1-5)
  dynamic _selectedService; // This should be your service model type

  void _loadTrainingData() {
    _trainingData = _predictionModel.getTrainingData();
  }

  @override
  void initState() {
    super.initState();
    _loadTrainingData();
  }

  // Show algorithm selection dialog
  void _showAlgorithmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Prediction Algorithm'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _algorithms.length,
              itemBuilder: (context, index) {
                final algoName = _algorithms.keys.elementAt(index);
                final algo = _algorithms[algoName]!;
                return ListTile(
                  leading: Icon(algo['icon'] as IconData, color: algo['color'] as Color),
                  title: Text(algoName),
                  subtitle: Text(algo['description'] as String),
                  trailing: _currentAlgorithm == algoName
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _currentAlgorithm = algoName;
                    });
                    Navigator.of(context).pop();
                    _predictEta(); // Recalculate with new algorithm
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Get the current algorithm's icon and color
  Widget _getAlgorithmChip() {
    final algo = _algorithms[_currentAlgorithm]!;
    final isNaiveBayes = _currentAlgorithm == 'Naive Bayes';
    
    return GestureDetector(
      onTap: _showAlgorithmDialog,
      child: Chip(
        avatar: isNaiveBayes 
            ? const Icon(Icons.check_circle, color: Colors.white)
            : Icon(algo['icon'] as IconData, color: Colors.white),
        label: Text(
          _currentAlgorithm,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isNaiveBayes 
            ? Colors.purple // Special color for Naive Bayes
            : algo['color'] as Color,
        side: isNaiveBayes 
            ? BorderSide(color: Colors.purple.shade700, width: 1.5)
            : BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: isNaiveBayes ? 3.0 : 1.0,
      ),
    );
  }

  // Instance of the prediction model
  Future<void> _predictEta() async {
    if (_selectedDate == null || _selectedTime == null) return;
    
    // Get current location or use default values
    double distanceKm = 5.0; // Default distance in km
    if (_geoPoint != null) {
      // In a real app, you would calculate the actual distance between provider and customer
      distanceKm = 5.0;
    }
    
    // Calculate time since last booking (or use a default if first booking)
    double timeSinceLast = 60.0; // Default 60 minutes
    if (_trainingData.isNotEmpty) {
      final lastBooking = _trainingData.last;
      timeSinceLast = 60.0; // Default fallback
      try {
        final lastTime = DateTime.now().subtract(Duration(minutes: lastBooking[10].toInt()));
        timeSinceLast = DateTime.now().difference(lastTime).inMinutes.toDouble();
      } catch (e) {
        print('Error calculating time since last booking: $e');
      }
    }
    
    // Prepare features for prediction as doubles
    final doubleFeatures = <double>[
      _selectedTime!.hour.toDouble(),
      _selectedDate!.weekday.toDouble(),
      _selectedService?.id?.toDouble() ?? 2.0,
      distanceKm.toDouble(),
      _trafficLevel.toDouble(),
      timeSinceLast.toDouble(),
    ];
    
    // Get prediction based on selected algorithm
    double eta = 30.0; // Default ETA in minutes
    try {
      switch (_currentAlgorithm) {
        case 'Decision Tree':
          eta = _predictionModel.predictWithDecisionTree(doubleFeatures);
          break;
        case 'K-Nearest Neighbors':
          eta = _predictionModel.predictWithKNN(doubleFeatures);
          break;
        case 'SVM':
          eta = _predictionModel.predictWithSVM(doubleFeatures);
          break;
        case 'Neural Network':
          eta = _predictionModel.predictWithNeuralNetwork(doubleFeatures);
          break;
        case 'Naive Bayes':
          // Fallback to KNN if Naive Bayes is not implemented
          eta = _predictionModel.predictWithKNN(doubleFeatures);
          break;
        default:
          eta = _predictionModel.predictWithDecisionTree(doubleFeatures);
      }
    } catch (e) {
      print('Error predicting ETA: $e');
      // Fallback to a default value if prediction fails
      eta = 30.0;
    }
    
    // Get optimal time suggestion if we don't have one yet
    if (_suggestedTime == null) {
      _suggestOptimalTime();
    }
    
    // Add this booking to training data
    _predictionModel.addBookingToTrainingData(
      _selectedTime ?? DateTime.now(),
      _selectedService.id is int ? _selectedService.id : 2, // Default to 2 if id is not int
      distanceKm,
      _trafficLevel,
      _selectedService.duration is double ? _selectedService.duration : 60.0, // Default to 60.0 if duration is not double
      timeSinceLast,
    );
    
    setState(() {
      _predictedEta = eta;
    });
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
        _predictedEta = null; // Reset ETA when time changes
      });
      // Predict ETA after setting the new time
      _predictEta();
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

      // Slot allocation: enforce exclusivity for On Time bookings based on estimated duration
      // Define candidate interval
      final int candidateMinutes = _onTime ? 60 : (_estimatedDays * 8 * 60);
      final DateTime candidateStart = finalDateTime;
      final DateTime candidateEnd = candidateStart.add(Duration(minutes: candidateMinutes));

      // For On Time bookings, check for any overlapping pending/accepted requests for this provider
      if (_onTime) {
        // Query same-day bookings to reduce reads
        final DateTime dayStart = DateTime(candidateStart.year, candidateStart.month, candidateStart.day);
        final DateTime dayEnd = DateTime(candidateStart.year, candidateStart.month, candidateStart.day, 23, 59, 59, 999);

        bool overlaps = false;
        try {
          final q = await FirebaseFirestore.instance
              .collection('serviceRequests')
              .where('providerId', isEqualTo: widget.providerId)
              .where('status', whereIn: ['pending', 'accepted'])
              .where('scheduledDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
              .where('scheduledDateTime', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
              .get();

          for (final d in q.docs) {
            final data = d.data() as Map<String, dynamic>;
            final Timestamp? ts = data['scheduledDateTime'] as Timestamp?;
            if (ts == null) continue;
            final DateTime otherStart = ts.toDate();
            final bool otherOnTime = (data['onTime'] == true);
            final int otherMinutes = otherOnTime
                ? 60
                : (((data['estimatedDurationDays'] as int?) ?? 1) * 8 * 60);
            final DateTime otherEnd = otherStart.add(Duration(minutes: otherMinutes));

            final bool isOverlap = otherStart.isBefore(candidateEnd) && candidateStart.isBefore(otherEnd);
            if (isOverlap && (otherOnTime || _onTime)) {
              overlaps = true;
              break;
            }
          }
        } catch (e) {
          // If we cannot read provider bookings due to security rules, skip the pre-check gracefully
          // and allow the booking to proceed. This preserves your rule logic.
          overlaps = false;
        }

        if (overlaps) {
          // Send customer notification: Slot is Full
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': user.uid,
            'createdBy': user.uid,
            'type': 'slot_full',
            'title': 'Slot is Full',
            'body': 'The selected time is not available for On Time service. Please choose another time.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected slot is full. Please choose another time.')),
            );
          }
          return; // do not create booking
        }
      }

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
          // store digits-only to align with rules (^\d{10,15}$)
          'phone': phoneDigits,
        },
        'accessNotes': _accessNotesCtrl.text.trim(),

        // Job details
        'instructions': _instructionsCtrl.text.trim(),
        if (_attachmentUrls.isNotEmpty) 'attachments': _attachmentUrls,
        'estimatedDurationDays': _estimatedDays,
        'onTime': _onTime,
        // Optionally store derived minutes for future overlap checks
        'estimatedDurationMinutes': candidateMinutes,
      });

      // If On Time, immediately mark as 'on_the_way' so timeline reflects the journey start
      if (_onTime) {
        try {
          await reqRef.update({
            'status': 'on_the_way',
            'onTheWayAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.deepPurple),
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
                    trailing: _predictedEta != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'ETA: ~${_predictedEta!.toStringAsFixed(0)} min',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            ],
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Algorithm info card
                  GestureDetector(
                    onTap: () {
                      // Toggle between algorithms
                      setState(() {
                        _currentAlgorithm = _currentAlgorithm == 'Decision Tree' 
                            ? 'K-Nearest Neighbors' 
                            : 'Decision Tree';
                        // Re-predict with the new algorithm
                        _predictEta();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _algorithms[_currentAlgorithm]!['color']!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _algorithms[_currentAlgorithm]!['color']!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _algorithms[_currentAlgorithm]!['icon'],
                                size: 16,
                                color: _algorithms[_currentAlgorithm]!['color'],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Using: $_currentAlgorithm',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _algorithms[_currentAlgorithm]!['color'],
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const Spacer(),
                              const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to switch',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _algorithms[_currentAlgorithm]!['description'],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[700],
                                  fontSize: 10,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4.0,
                            runSpacing: 2.0,
                            children: (_algorithms[_currentAlgorithm]!['features'] as List<dynamic>).map<Widget>((dynamic feature) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _algorithms[_currentAlgorithm]!['color']!.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: _algorithms[_currentAlgorithm]!['color'],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      feature,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[800],
                                            fontSize: 9,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                                        '• Based on ${_trainingData.length} previous bookings',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          
                          const SizedBox(height: 8),
                          
                          // Algorithm info card
                          GestureDetector(
                            onTap: () {
                              // Toggle between algorithms
                              setState(() {
                                _currentAlgorithm = _currentAlgorithm == 'Decision Tree' 
                                    ? 'K-Nearest Neighbors' 
                                    : 'Decision Tree';
                                // Re-predict with the new algorithm
                                _predictEta();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _algorithms[_currentAlgorithm]!['color']!.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _algorithms[_currentAlgorithm]!['color']!.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _algorithms[_currentAlgorithm]!['icon'],
                                        size: 16,
                                        color: _algorithms[_currentAlgorithm]!['color'],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Using: $_currentAlgorithm',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: _algorithms[_currentAlgorithm]!['color'],
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Tap to switch',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                              fontSize: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _algorithms[_currentAlgorithm]!['description'],
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[700],
                                          fontSize: 10,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4.0,
                                    runSpacing: 2.0,
                                    children: (_algorithms[_currentAlgorithm]!['features'] as List<dynamic>).map<Widget>((dynamic feature) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _algorithms[_currentAlgorithm]!['color']!.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 12,
                                              color: _algorithms[_currentAlgorithm]!['color'],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              feature,
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Colors.grey[800],
                                                    fontSize: 9,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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