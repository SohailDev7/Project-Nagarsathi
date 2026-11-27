import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/citizen_location.dart';
import '../utils/ward_lookup.dart';

/// Thrown when the ward cannot be detected. The message is citizen-friendly.
class LocationFailure implements Exception {
  const LocationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Asks for the device location once, reverse geocodes it and turns it into a
/// municipality + ward the citizen can confirm.
class LocationService {
  const LocationService();

  /// Returns the detected ward, or `null` when the citizen dismisses the
  /// system permission prompt.
  Future<CitizenLocation?> detect() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) return null;
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Location is blocked. Allow it in system settings to find your ward.',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure('Turn on location so we can find your ward.');
    }

    final position = await _position();
    if (position == null) {
      throw const LocationFailure(
        "We couldn't get a location fix. Move somewhere open and try again.",
      );
    }

    final placemarks = await _placemarks(position);
    if (placemarks.isEmpty) {
      throw const LocationFailure(
        "We couldn't read the address for this spot. Please try again.",
      );
    }

    final mark = placemarks.first;
    final ward =
        WardLookup.wardFrom([
          mark.subLocality,
          mark.locality,
          mark.subAdministrativeArea,
          mark.name,
          mark.street,
          mark.thoroughfare,
          mark.administrativeArea,
        ]) ??
        WardLookup.wardNumber(mark.subLocality);
    if (ward == null) {
      throw const LocationFailure(
        "We couldn't read your ward here. Try again from your home lane.",
      );
    }

    final municipality = WardLookup.municipalityFrom([
      mark.subAdministrativeArea,
      mark.locality,
      mark.subLocality,
      mark.administrativeArea,
    ]);
    if (municipality == null) {
      throw const LocationFailure(
        "We couldn't read your municipality here. Please try again.",
      );
    }

    return CitizenLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      municipality: municipality,
      ward: ward,
    );
  }

  /// Last fix the device already has, without prompting for permission. Used to
  /// keep real coordinates when the citizen picks the ward by hand.
  Future<({double latitude, double longitude})?> lastKnownFix() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _position() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<Placemark>> _placemarks(Position position) async {
    try {
      return await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (_) {
      throw const LocationFailure(
        "We found your position but couldn't read the address. Please try again.",
      );
    }
  }
}
