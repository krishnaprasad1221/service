import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Tracks provider location while a booking is `on_the_way` and writes
/// live ETA updates to `serviceRequests/{requestId}.tracking`.
class ProviderLiveTrackingService {
  ProviderLiveTrackingService._();

  static final ProviderLiveTrackingService instance =
      ProviderLiveTrackingService._();

  static const Duration _minWriteGap = Duration(seconds: 12);
  static const Duration _minDeviationAlertGap = Duration(minutes: 10);
  static const int _deviationThresholdMinutes = 10;
  static const double _avgSpeedMetersPerMinute = 420.0; // ~25 km/h

  final Map<String, StreamSubscription<Position>> _subscriptionsByRequest =
      <String, StreamSubscription<Position>>{};
  final Map<String, DateTime> _lastWriteByRequest = <String, DateTime>{};
  final Set<String> _inFlightUpdates = <String>{};

  bool isTracking(String requestId) => _subscriptionsByRequest.containsKey(requestId);

  Future<void> resumeActiveTrackingForCurrentProvider() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .where('providerId', isEqualTo: uid)
          .limit(50)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? 'pending';
        if (status == 'on_the_way') {
          await ensureTrackingForRequest(doc.id);
        }
      }
    } catch (_) {
      // Keep dashboard flow resilient if tracking bootstrap fails.
    }
  }

  Future<void> onStatusChanged({
    required String requestId,
    required String newStatus,
  }) async {
    if (newStatus == 'on_the_way') {
      await ensureTrackingForRequest(requestId);
      return;
    }
    if (isTracking(requestId)) {
      await stopTrackingForRequest(requestId, markStopped: true);
    }
  }

  Future<void> ensureTrackingForRequest(String requestId) async {
    if (_subscriptionsByRequest.containsKey(requestId)) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    final reqRef =
        FirebaseFirestore.instance.collection('serviceRequests').doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists || reqSnap.data() == null) return;

    final data = reqSnap.data()!;
    final providerId = (data['providerId'] as String?) ?? '';
    final status = (data['status'] as String?) ?? 'pending';

    if (providerId != uid || status != 'on_the_way') return;

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    );

    _subscriptionsByRequest[requestId] = stream.listen(
      (position) => _handlePositionUpdate(
        requestId: requestId,
        requestRef: reqRef,
        position: position,
      ),
      onError: (_) async {
        await stopTrackingForRequest(requestId, markStopped: false);
      },
    );
  }

  Future<void> stopTrackingForRequest(
    String requestId, {
    required bool markStopped,
  }) async {
    final sub = _subscriptionsByRequest.remove(requestId);
    await sub?.cancel();
    _lastWriteByRequest.remove(requestId);
    _inFlightUpdates.remove(requestId);

    if (!markStopped) return;

    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(requestId)
          .update(<String, dynamic>{
        'tracking.isLive': false,
        'tracking.stoppedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-blocking; journey status transition should not fail.
    }
  }

  Future<void> stopAllTracking() async {
    final requestIds = _subscriptionsByRequest.keys.toList();
    for (final requestId in requestIds) {
      await stopTrackingForRequest(requestId, markStopped: false);
    }
  }

  Future<void> _handlePositionUpdate({
    required String requestId,
    required DocumentReference<Map<String, dynamic>> requestRef,
    required Position position,
  }) async {
    if (_inFlightUpdates.contains(requestId)) return;

    final now = DateTime.now();
    final lastWrite = _lastWriteByRequest[requestId];
    if (lastWrite != null && now.difference(lastWrite) < _minWriteGap) {
      return;
    }

    _inFlightUpdates.add(requestId);
    _lastWriteByRequest[requestId] = now;

    try {
      final reqSnap = await requestRef.get();
      if (!reqSnap.exists || reqSnap.data() == null) {
        await stopTrackingForRequest(requestId, markStopped: false);
        return;
      }

      final data = reqSnap.data()!;
      final status = (data['status'] as String?) ?? 'pending';
      if (status != 'on_the_way') {
        await stopTrackingForRequest(requestId, markStopped: true);
        return;
      }

      final GeoPoint? destinationGeo = _extractDestinationGeo(data);
      final trackingMap = (data['tracking'] is Map)
          ? Map<String, dynamic>.from(data['tracking'] as Map)
          : <String, dynamic>{};

      int? etaMinutes;
      int? deviationMinutes;
      int? initialEtaMinutes = _toInt(trackingMap['initialEtaMinutes']);

      if (destinationGeo != null) {
        final distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destinationGeo.latitude,
          destinationGeo.longitude,
        );
        etaMinutes = _estimateEtaMinutes(distanceMeters);
        initialEtaMinutes ??= etaMinutes;
        deviationMinutes = etaMinutes - initialEtaMinutes;
      }

      final updates = <String, dynamic>{
        'tracking.providerGeo': GeoPoint(position.latitude, position.longitude),
        'tracking.updatedAt': FieldValue.serverTimestamp(),
        'tracking.isLive': true,
      };
      if (etaMinutes != null) {
        updates['tracking.etaMinutes'] = etaMinutes;
      }
      if (initialEtaMinutes != null) {
        updates['tracking.initialEtaMinutes'] = initialEtaMinutes;
      }
      if (deviationMinutes != null) {
        updates['tracking.deviationMinutes'] = deviationMinutes;
      }

      await requestRef.update(updates);

      if (etaMinutes != null &&
          initialEtaMinutes != null &&
          deviationMinutes != null &&
          deviationMinutes >= _deviationThresholdMinutes) {
        await _maybeSendDeviationAlert(
          requestRef: requestRef,
          requestId: requestId,
          requestData: data,
          currentEtaMinutes: etaMinutes,
          deviationMinutes: deviationMinutes,
          trackingMap: trackingMap,
        );
      }
    } catch (_) {
      // Avoid crashing stream processing for transient failures.
    } finally {
      _inFlightUpdates.remove(requestId);
    }
  }

  Future<void> _maybeSendDeviationAlert({
    required DocumentReference<Map<String, dynamic>> requestRef,
    required String requestId,
    required Map<String, dynamic> requestData,
    required int currentEtaMinutes,
    required int deviationMinutes,
    required Map<String, dynamic> trackingMap,
  }) async {
    final lastAlertTs = trackingMap['lastDeviationAlertAt'];
    DateTime? lastAlertAt;
    if (lastAlertTs is Timestamp) {
      lastAlertAt = lastAlertTs.toDate();
    }
    if (lastAlertAt != null &&
        DateTime.now().difference(lastAlertAt) < _minDeviationAlertGap) {
      return;
    }

    final customerId = (requestData['customerId'] as String?) ?? '';
    if (customerId.isEmpty) return;

    final serviceName =
        (requestData['serviceName'] as String?) ?? 'your service request';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await requestRef.update(<String, dynamic>{
        'tracking.lastDeviationAlertAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add(
        <String, dynamic>{
          'userId': customerId,
          'createdBy': uid,
          'type': 'eta_deviation',
          'title': 'Arrival delay update',
          'body':
              'Provider ETA for $serviceName is now about $currentEtaMinutes min (delay +$deviationMinutes min).',
          'relatedId': requestId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // Non-critical.
    }
  }

  Future<bool> _ensureLocationPermission() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  GeoPoint? _extractDestinationGeo(Map<String, dynamic> data) {
    final geoSnapshot = data['geoSnapshot'];
    if (geoSnapshot is GeoPoint) return geoSnapshot;
    final location = data['location'];
    if (location is GeoPoint) return location;
    return null;
  }

  int _estimateEtaMinutes(double distanceMeters) {
    if (distanceMeters <= 60) return 1;
    final eta = (distanceMeters / _avgSpeedMetersPerMinute).ceil();
    return math.max(1, math.min(180, eta));
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
