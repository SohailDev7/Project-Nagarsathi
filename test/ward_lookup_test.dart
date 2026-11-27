import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/models/citizen_location.dart';
import 'package:projectnagarsathi/utils/ward_lookup.dart';

void main() {
  group('WardLookup.wardFrom', () {
    test('reads common ward formats', () {
      expect(WardLookup.wardFrom(['Ward 16']), 16);
      expect(WardLookup.wardFrom(['Kathmandu Ward No. 16']), 16);
      expect(WardLookup.wardFrom(['WARD - 6']), 6);
      expect(WardLookup.wardFrom(['ward-31, Kathmandu']), 31);
      expect(WardLookup.wardFrom([null, '', 'Ward Number 4']), 4);
      expect(WardLookup.wardFrom(['Ward16']), 16);
    });

    test('reads Nepali and keyword-less ward text', () {
      expect(WardLookup.wardFrom(['वडा १६']), 16);
      expect(WardLookup.wardFrom(['काठमाडौं वडा नं. १६']), 16);
      expect(WardLookup.wardFrom(['16, Kathmandu']), 16);
      expect(WardLookup.wardFrom(['Kathmandu, 16']), 16);
    });

    test('ignores numbers that are not wards', () {
      expect(WardLookup.wardFrom(['Kathmandu 44600']), isNull);
      expect(WardLookup.wardFrom(['New Baneshwor, Street 12']), isNull);
      expect(WardLookup.wardFrom(['Ward 0']), isNull);
      expect(WardLookup.wardFrom(['Ward 99']), isNull);
      expect(WardLookup.wardFrom([]), isNull);
    });

    test('accepts a bare ward number in the sub-locality', () {
      expect(WardLookup.wardNumber('16'), 16);
      expect(WardLookup.wardNumber(' 6 '), 6);
      expect(WardLookup.wardNumber('Street 16'), isNull);
      expect(WardLookup.wardNumber('0'), isNull);
      expect(WardLookup.wardNumber('44600'), isNull);
      expect(WardLookup.wardNumber(null), isNull);
    });
  });

  group('WardLookup.municipalityFrom', () {
    test('expands known metropolitan cities', () {
      expect(
        WardLookup.municipalityFrom(['Kathmandu']),
        'Kathmandu Metropolitan City',
      );
      expect(
        WardLookup.municipalityFrom(['Kathmandu Metropolitan City']),
        'Kathmandu Metropolitan City',
      );
      expect(
        WardLookup.municipalityFrom(['Lalitpur']),
        'Lalitpur Metropolitan City',
      );
    });

    test('keeps other municipalities as reported', () {
      expect(WardLookup.municipalityFrom(['Bhaktapur']), 'Bhaktapur');
    });

    test('skips ward text and country noise', () {
      expect(
        WardLookup.municipalityFrom(['Ward 16', 'Nepal', 'Bhaktapur']),
        'Bhaktapur',
      );
      expect(WardLookup.municipalityFrom(['Nepal', '44600']), isNull);
    });
  });

  group('CitizenLocation', () {
    const location = CitizenLocation(
      latitude: 27.6896,
      longitude: 85.3427,
      municipality: 'Kathmandu Metropolitan City',
      ward: 16,
    );

    test('builds the ward label', () {
      expect(location.municipalityCode, 'KMC');
      expect(location.label, 'KMC WARD -16');
    });

    test('uses the full name when no short code is possible', () {
      const single = CitizenLocation(
        latitude: 27.67,
        longitude: 85.43,
        municipality: 'Bhaktapur',
        ward: 9,
      );
      expect(single.label, 'Bhaktapur WARD -9');
    });

    test('round trips through Firestore-friendly maps', () {
      final restored = CitizenLocation.tryFromMap(location.toMap());
      expect(restored, isNotNull);
      expect(restored!.label, location.label);
      expect(restored.latitude, location.latitude);
      expect(restored.longitude, location.longitude);
    });

    test('ignores malformed stored values', () {
      expect(CitizenLocation.tryFromMap(null), isNull);
      expect(CitizenLocation.tryFromMap({'ward': 16}), isNull);
      expect(
        CitizenLocation.tryFromMap({
          'ward': '16',
          'municipality': 'Kathmandu',
          'latitude': 27.6,
          'longitude': 85.3,
        }),
        isNull,
      );
    });
  });
}
