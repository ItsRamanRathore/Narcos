import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationData {
  final String source; // 'gps', 'last_known', 'unavailable'
  final String lat;
  final String lng;
  final int accuracyMeters;
  final bool isStale;
  final int? staleSinceMs;
  final String? address;

  LocationData({
    required this.source,
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
    this.isStale = false,
    this.staleSinceMs,
    this.address,
  });

  factory LocationData.unavailable() {
    return LocationData(
      source: 'unavailable',
      lat: '0.000000',
      lng: '0.000000',
      accuracyMeters: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'lat': lat,
      'lng': lng,
      'accuracy_meters': accuracyMeters,
      'is_stale': isStale,
      if (staleSinceMs != null) 'stale_since_ms': staleSinceMs,
      if (address != null) 'address': address,
    };
  }
}

class LocationService {
  static Future<LocationData> captureLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationData.unavailable();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return LocationData.unavailable(); // Assume permission requested earlier in UI
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationData.unavailable();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude).timeout(const Duration(seconds: 2));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = '\${p.street}, \${p.locality}, \${p.administrativeArea} \${p.postalCode}, \${p.country}';
        }
      } catch (_) {
        // Reverse geocoding failed or offline
      }

      return LocationData(
        source: 'gps',
        lat: position.latitude.toStringAsFixed(6),
        lng: position.longitude.toStringAsFixed(6),
        accuracyMeters: position.accuracy.toInt(),
        address: address,
      );
    } on TimeoutException {
      // Try last known position as fallback
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationData(
          source: 'last_known',
          lat: last.latitude.toStringAsFixed(6),
          lng: last.longitude.toStringAsFixed(6),
          accuracyMeters: last.accuracy.toInt(),
          isStale: true,
          staleSinceMs: DateTime.now().millisecondsSinceEpoch - last.timestamp.millisecondsSinceEpoch,
        );
      }
      return LocationData.unavailable();
    } catch (_) {
      return LocationData.unavailable();
    }
  }
}
