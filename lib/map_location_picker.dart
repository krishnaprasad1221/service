import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Simple map location picker. Returns a human-readable address string on
// successful selection, or null if cancelled.
class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({super.key});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _pickedLatLng;
  String _addressPreview = 'Tap on map or move marker to pick location';
  bool _loading = true;

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(13.0827, 80.2707), // Chennai fallback
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final LocationPermission asked = await Geolocator.requestPermission();
        if (asked == LocationPermission.denied || asked == LocationPermission.deniedForever) {
          setState(() => _loading = false);
          return;
        }
      }

      final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final LatLng cur = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pickedLatLng = cur;
        _loading = false;
      });
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: cur, zoom: 16)));
      await _refreshAddressFor(cur);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshAddressFor(LatLng latLng) async {
    try {
      final List<geocoding.Placemark> places = await geocoding.placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = <String>[];
        if (p.street != null && p.street!.trim().isNotEmpty) parts.add(p.street!.trim());
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) parts.add(p.subLocality!.trim());
        if (p.locality != null && p.locality!.trim().isNotEmpty) parts.add(p.locality!.trim());
        if (p.postalCode != null && p.postalCode!.trim().isNotEmpty) parts.add(p.postalCode!.trim());
        if (p.country != null && p.country!.trim().isNotEmpty) parts.add(p.country!.trim());
        setState(() {
          _addressPreview = parts.join(', ');
        });
      } else {
        setState(() {
          _addressPreview = '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
        });
      }
    } catch (_) {
      setState(() {
        _addressPreview = '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!_controller.isCompleted) _controller.complete(controller);
  }

  void _onTap(LatLng latLng) async {
    setState(() => _pickedLatLng = latLng);
    await _refreshAddressFor(latLng);
  }

  @override
  Widget build(BuildContext context) {
    final Marker? marker = _pickedLatLng == null
        ? null
        : Marker(
            markerId: const MarkerId('picked'),
            position: _pickedLatLng!,
            draggable: true,
            onDragEnd: (p) async {
              setState(() => _pickedLatLng = p);
              await _refreshAddressFor(p);
            },
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick delivery location'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: _pickedLatLng == null ? _defaultCamera : CameraPosition(target: _pickedLatLng!, zoom: 16),
                  onMapCreated: _onMapCreated,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: _onTap,
                  markers: marker == null ? const <Marker>{} : <Marker>{marker},
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Selected: ',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  _addressPreview,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        onPressed: _pickedLatLng == null
                            ? null
                            : () {
                                Navigator.of(context).pop(_addressPreview);
                              },
                        child: const Text('Select Location'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
