import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_webview_screen.dart';

class CustomerLiveTrackingScreen extends StatelessWidget {
  final String requestId;

  const CustomerLiveTrackingScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(requestId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Booking not found.'));
          }

          final data = snapshot.data!.data()!;
          final status = (data['status'] as String?) ?? 'pending';
          final serviceName = (data['serviceName'] as String?) ?? 'Service';

          final tracking = (data['tracking'] is Map)
              ? Map<String, dynamic>.from(data['tracking'] as Map)
              : <String, dynamic>{};

          final GeoPoint? providerGeo = _toGeo(tracking['providerGeo']);
          final GeoPoint? customerGeo =
              _toGeo(data['geoSnapshot']) ?? _toGeo(data['location']);

          final int? etaMinutes = _toInt(tracking['etaMinutes']);
          final int? deviationMinutes = _toInt(tracking['deviationMinutes']);
          final bool isLive = (tracking['isLive'] == true) && status == 'on_the_way';
          final DateTime? updatedAt = _toDateTime(tracking['updatedAt']);

          final bool hasRoute = providerGeo != null && customerGeo != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headerCard(
                serviceName: serviceName,
                status: status,
                isLive: isLive,
                etaMinutes: etaMinutes,
                deviationMinutes: deviationMinutes,
                updatedAt: updatedAt,
              ),
              const SizedBox(height: 12),
              _locationCard(
                providerGeo: providerGeo,
                customerGeo: customerGeo,
              ),
              const SizedBox(height: 16),
              if (status == 'on_the_way' && providerGeo == null)
                const Text(
                  'Provider journey has started. Waiting for first live location update...',
                  style: TextStyle(color: Colors.black54),
                ),
              if (status != 'on_the_way' && status != 'arrived')
                const Text(
                  'Live tracking is available when the booking is on the way.',
                  style: TextStyle(color: Colors.black54),
                ),
              const SizedBox(height: 12),
              if (hasRoute)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.route),
                    label: const Text('Open Live Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      _openLiveRoute(context, providerGeo, customerGeo);
                    },
                  ),
                ),
              if (hasRoute)
                const SizedBox(height: 8),
              if (hasRoute)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open in Maps App'),
                    onPressed: () =>
                        _openInMapsApp(context, providerGeo, customerGeo),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard({
    required String serviceName,
    required String status,
    required bool isLive,
    required int? etaMinutes,
    required int? deviationMinutes,
    required DateTime? updatedAt,
  }) {
    final String etaLabel =
        etaMinutes == null ? 'Calculating...' : '~$etaMinutes min';
    final bool delayed = (deviationMinutes ?? 0) >= 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(
                isLive ? 'Live' : status.toUpperCase(),
                color: isLive ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              _chip('ETA $etaLabel', color: Colors.white70, textColor: Colors.black87),
              if (delayed) ...[
                const SizedBox(width: 8),
                _chip('+${deviationMinutes}m delay', color: Colors.redAccent),
              ],
            ],
          ),
          if (updatedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last update: ${DateFormat.yMMMd().add_jm().format(updatedAt)}',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _locationCard({
    required GeoPoint? providerGeo,
    required GeoPoint? customerGeo,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Coordinates',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _geoRow(
              icon: Icons.motorcycle,
              title: 'Provider',
              geo: providerGeo,
            ),
            const SizedBox(height: 8),
            _geoRow(
              icon: Icons.home_outlined,
              title: 'Your Location',
              geo: customerGeo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _geoRow({
    required IconData icon,
    required String title,
    required GeoPoint? geo,
  }) {
    final String value = geo == null
        ? 'Not available'
        : '${geo.latitude.toStringAsFixed(6)}, ${geo.longitude.toStringAsFixed(6)}';
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.deepPurple),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _chip(
    String label, {
    required Color color,
    Color textColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  GeoPoint? _toGeo(dynamic v) {
    if (v is GeoPoint) return v;
    return null;
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  DateTime? _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  Uri _routeUri(GeoPoint providerGeo, GeoPoint customerGeo) {
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${providerGeo.latitude},${providerGeo.longitude}'
      '&destination=${customerGeo.latitude},${customerGeo.longitude}'
      '&travelmode=driving',
    );
  }

  Future<void> _openLiveRoute(
    BuildContext context,
    GeoPoint providerGeo,
    GeoPoint customerGeo,
  ) async {
    // Web keeps in-app route preview. Mobile opens external maps directly
    // to avoid device-specific WebView rendering issues.
    if (kIsWeb) {
      final route = _routeUri(providerGeo, customerGeo);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapWebViewScreen(
            url: route,
            title: 'Provider Route',
          ),
        ),
      );
      return;
    }

    final launched = await _openInMapsExternally(providerGeo, customerGeo);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open route in Maps app.')),
      );
    }
  }

  Future<void> _openInMapsApp(
    BuildContext context,
    GeoPoint providerGeo,
    GeoPoint customerGeo,
  ) async {
    final launched = await _openInMapsExternally(providerGeo, customerGeo);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps app.')),
      );
    }
  }

  Future<bool> _openInMapsExternally(
    GeoPoint providerGeo,
    GeoPoint customerGeo,
  ) async {
    final routeWeb = _routeUri(providerGeo, customerGeo);
    final navUri = Uri.parse(
      'google.navigation:q=${customerGeo.latitude},${customerGeo.longitude}&mode=d',
    );
    final geoUri = Uri.parse(
      'geo:${customerGeo.latitude},${customerGeo.longitude}?q=${customerGeo.latitude},${customerGeo.longitude}(Destination)',
    );

    final candidates = <Uri>[navUri, routeWeb, geoUri];
    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched =
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (_) {
        // Try next candidate.
      }
    }
    return false;
  }
}
