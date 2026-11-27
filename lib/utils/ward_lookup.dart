/// Turns reverse-geocoded address parts into a Nepali municipality and ward.
///
/// Device geocoders rarely agree on which [Placemark] field carries the ward
/// ("Ward 16", "Ward No. 16", "WARD-16", "वडा १६" are all common), and some
/// devices leave the word "ward" out entirely. Every text field is scanned for
/// a ward keyword first, then for a bare ward-sized number.
abstract final class WardLookup {
  static final _wardPattern = RegExp(
    r'ward\s*(?:no\.?|number|#)?\s*[-–—:.]?\s*(\d{1,2})',
    caseSensitive: false,
  );

  static final _nepaliWardPattern = RegExp(
    r'वडा\s*(?:नं\.?|नम्बर)?\s*[-–—:.]?\s*([०-९\d]{1,2})',
  );

  /// A part that is only a ward number, optionally prefixed by "ward"/"वडा".
  static final _wardTokenPattern = RegExp(
    r'^(?:ward|w|वडा)?\s*[-–—#:.]?\s*(\d{1,2})$',
    caseSensitive: false,
  );

  static final _nepaliDigits = RegExp(r'[०-९]');

  /// Known metropolitan cities, mapped to their official name so the ward
  /// label reads like the ones citizens see on ward office signage.
  static const _metropolitanCities = {
    'kathmandu': 'Kathmandu Metropolitan City',
    'lalitpur': 'Lalitpur Metropolitan City',
    'pokhara': 'Pokhara Metropolitan City',
    'bharatpur': 'Bharatpur Metropolitan City',
    'biratnagar': 'Biratnagar Metropolitan City',
    'birgunj': 'Birgunj Metropolitan City',
    'janakpur': 'Janakpur Sub-Metropolitan City',
  };

  /// Highest ward number in Nepal (Kathmandu has 32); anything above is noise.
  static const _maxWard = 35;

  /// Reads the first plausible ward number from [parts], if any.
  static int? wardFrom(Iterable<String?> parts) {
    for (final part in parts) {
      if (part == null) continue;
      final text = _toAsciiDigits(part);
      final match =
          _wardPattern.firstMatch(text) ?? _nepaliWardPattern.firstMatch(part);
      if (match == null) continue;
      final ward = int.tryParse(_toAsciiDigits(match.group(1)!));
      if (ward != null && ward >= 1 && ward <= _maxWard) return ward;
    }

    // No "ward" keyword anywhere: accept a field or comma-separated token that
    // is only a ward-sized number, e.g. "16" or "Kathmandu, 16".
    for (final part in parts) {
      if (part == null) continue;
      for (final token in _toAsciiDigits(part).split(RegExp(r'[,/|;]'))) {
        final match = _wardTokenPattern.firstMatch(token.trim());
        if (match == null) continue;
        final ward = int.tryParse(match.group(1)!);
        if (ward != null && ward >= 1 && ward <= _maxWard) return ward;
      }
    }
    return null;
  }

  /// Some geocoders put the ward in the sub-locality as a bare number, e.g.
  /// `"16"`. Only use this on a field that is nothing but the number.
  static int? wardNumber(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null) return null;
    final text = _toAsciiDigits(trimmed);
    if (!RegExp(r'^\d{1,2}$').hasMatch(text)) return null;
    final ward = int.tryParse(text);
    return (ward != null && ward >= 1 && ward <= _maxWard) ? ward : null;
  }

  /// Reads the municipality from [parts], preferring a known metropolitan city.
  ///
  /// [parts] should be ordered from most to least specific.
  static String? municipalityFrom(Iterable<String?> parts) {
    final candidates = <String>[];

    for (final part in parts) {
      final value = part?.trim();
      if (value == null || value.isEmpty) continue;
      if (_wardPattern.hasMatch(value) || _nepaliWardPattern.hasMatch(value)) {
        continue;
      }
      candidates.add(value);

      final lower = value.toLowerCase();
      for (final entry in _metropolitanCities.entries) {
        if (lower.contains(entry.key)) return entry.value;
      }
    }

    for (final value in candidates) {
      if (value.toLowerCase() == 'nepal') continue;
      if (RegExp(r'^\d').hasMatch(value)) continue;
      return value;
    }
    return null;
  }

  static String _toAsciiDigits(String value) => value.replaceAllMapped(
    _nepaliDigits,
    (match) => String.fromCharCode(
      match.group(0)!.codeUnitAt(0) - '०'.codeUnitAt(0) + '0'.codeUnitAt(0),
    ),
  );
}
