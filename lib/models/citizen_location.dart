/// The municipality and ward a citizen's reports should be routed to.
///
/// Stored in Firestore under `users/{uid}.location` so every device picks up
/// the same confirmed ward.
class CitizenLocation {
  const CitizenLocation({
    required this.latitude,
    required this.longitude,
    required this.municipality,
    required this.ward,
    this.source = sourceGps,
  });

  /// Coordinates came from a device fix.
  static const sourceGps = 'gps';

  /// The ward was picked by hand in the ward picker. The coordinates are then
  /// a real fix when one was available, otherwise the municipality centre.
  static const sourceManual = 'manual';

  final double latitude;
  final double longitude;
  final String municipality;
  final int ward;

  /// How this ward was established: [sourceGps] or [sourceManual].
  final String source;

  bool get isManual => source == sourceManual;

  /// Short code built from the municipality name, e.g. "KMC" for
  /// "Kathmandu Metropolitan City". Empty when the name has no usable words.
  String get municipalityCode {
    final words = municipality
        .split(RegExp(r'[^A-Za-z]+'))
        .where((word) => word.isNotEmpty);
    final code = words.map((word) => word[0].toUpperCase()).join();
    return code.length >= 2 ? code : '';
  }

  /// Label shown in the app, e.g. "KMC WARD -16".
  String get label {
    final code = municipalityCode;
    return '${code.isEmpty ? municipality : code} WARD -$ward';
  }

  Map<String, Object?> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'municipality': municipality,
    'ward': ward,
    'source': source,
  };

  static CitizenLocation? tryFromMap(Object? value) {
    if (value is! Map) return null;
    final ward = value['ward'];
    final municipality = value['municipality'];
    final latitude = value['latitude'];
    final longitude = value['longitude'];

    if (ward is! num || latitude is! num || longitude is! num) return null;
    if (municipality is! String || municipality.trim().isEmpty) return null;

    final source = value['source'];

    return CitizenLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      municipality: municipality,
      ward: ward.toInt(),
      source: source == sourceManual ? sourceManual : sourceGps,
    );
  }
}
