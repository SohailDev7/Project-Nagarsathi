/// The two metropolitan cities this app serves.
///
/// Each municipality has its own ward numbering, so an account always carries
/// both the municipality and the ward inside it.
enum Municipality {
  kmc('KMC', 'Kathmandu Metropolitan City', 32),
  lmc('LMC', 'Lalitpur Metropolitan City', 29);

  const Municipality(this.code, this.name, this.wardCount);

  /// Short code shown in labels and stored in Firestore, e.g. `KMC`.
  final String code;

  /// Official municipality name.
  final String name;

  /// Highest ward number in this municipality.
  final int wardCount;

  /// Compact picker label, e.g. `Kathmandu (KMC)`.
  String get label => '$name ($code)';

  /// Human-readable ward, e.g. `KMC · Ward 4`.
  String wardLabel(int ward) => '$code · Ward $ward';

  bool hasWard(int ward) => ward >= 1 && ward <= wardCount;

  /// Reads a stored code (`KMC`), official name, or free text. Unknown values
  /// fall back to Kathmandu, which is what pre-municipality records used.
  static Municipality fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return Municipality.kmc;

    for (final municipality in values) {
      if (normalized == municipality.code.toLowerCase() ||
          normalized == municipality.name.toLowerCase()) {
        return municipality;
      }
    }
    if (normalized.contains('lalitpur') || normalized.contains('lmc')) {
      return lmc;
    }
    if (normalized.contains('kathmandu') ||
        normalized.contains('ktm') ||
        normalized.contains('kmc')) {
      return kmc;
    }
    return kmc;
  }
}
