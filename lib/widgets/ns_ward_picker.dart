import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/citizen_location.dart';
import '../theme/app_theme.dart';
import 'ns_primary_button.dart';

/// Asks the citizen to choose their municipality and ward by hand.
///
/// Used when the phone's reverse geocoder returns no ward, which is common for
/// Nepali addresses, and whenever the citizen wants to correct a saved ward.
/// The result is marked `source: manual` in [CitizenLocation]; a real GPS fix is
/// kept when one was available.
Future<CitizenLocation?> showWardPicker(
  BuildContext context, {
  String? initialMunicipality,
  ({double latitude, double longitude})? fix,
}) {
  return showModalBottomSheet<CitizenLocation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _WardPickerSheet(initialMunicipality: initialMunicipality, fix: fix),
  );
}

class _WardPickerSheet extends StatefulWidget {
  const _WardPickerSheet({this.initialMunicipality, this.fix});

  final String? initialMunicipality;
  final ({double latitude, double longitude})? fix;

  @override
  State<_WardPickerSheet> createState() => _WardPickerSheetState();
}

class _WardPickerSheetState extends State<_WardPickerSheet> {
  late _MunicipalityOption _municipality;
  int? _ward;

  @override
  void initState() {
    super.initState();
    final hint = widget.initialMunicipality?.toLowerCase() ?? '';
    _municipality = _municipalities.firstWhere(
      (option) => hint.contains(option.name.toLowerCase().split(' ').first),
      orElse: () => _municipalities.first,
    );
  }

  void _selectMunicipality(_MunicipalityOption option) {
    if (option.code == _municipality.code) return;
    HapticFeedback.selectionClick();
    setState(() {
      _municipality = option;
      _ward = null;
    });
  }

  void _save() {
    final ward = _ward;
    if (ward == null) return;
    final fix = widget.fix;
    Navigator.of(context).pop(
      CitizenLocation(
        latitude: fix?.latitude ?? _municipality.latitude,
        longitude: fix?.longitude ?? _municipality.longitude,
        municipality: _municipality.name,
        ward: ward,
        source: CitizenLocation.sourceManual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tokens.border, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.chooseWardTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: tokens.heading,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                strings.chooseWardSubtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (
                    var index = 0;
                    index < _municipalities.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _MunicipalityChoice(
                        key: Key(
                          'ward-picker-'
                          '${_municipalities[index].code.toLowerCase()}',
                        ),
                        option: _municipalities[index],
                        selected:
                            _municipalities[index].code == _municipality.code,
                        onTap: () =>
                            _selectMunicipality(_municipalities[index]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 8.0;
                      const columns = 6;
                      final width =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (
                            var ward = 1;
                            ward <= _municipality.wardCount;
                            ward++
                          )
                            SizedBox(
                              width: width,
                              child: _WardChoice(
                                key: Key('ward-choice-$ward'),
                                ward: ward,
                                selected: ward == _ward,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _ward = ward);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              NsPrimaryButton(
                key: const Key('ward-picker-save'),
                label: strings.saveWard,
                icon: Icons.check_rounded,
                onPressed: _ward == null ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MunicipalityOption {
  const _MunicipalityOption({
    required this.name,
    required this.code,
    required this.wardCount,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String code;
  final int wardCount;
  final double latitude;
  final double longitude;
}

const _municipalities = [
  _MunicipalityOption(
    name: 'Kathmandu Metropolitan City',
    code: 'KMC',
    wardCount: 32,
    latitude: 27.7172,
    longitude: 85.3240,
  ),
  _MunicipalityOption(
    name: 'Lalitpur Metropolitan City',
    code: 'LMC',
    wardCount: 29,
    latitude: 27.6667,
    longitude: 85.3167,
  ),
];

class _MunicipalityChoice extends StatelessWidget {
  const _MunicipalityChoice({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _MunicipalityOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? tokens.mint : tokens.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? tokens.accentText : tokens.controlBorder,
              width: selected ? 1.8 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.code,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: tokens.heading,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                option.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WardChoice extends StatelessWidget {
  const _WardChoice({
    super.key,
    required this.ward,
    required this.selected,
    required this.onTap,
  });

  final int ward;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? tokens.accentText : tokens.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tokens.accentText : tokens.controlBorder,
              width: 1.4,
            ),
          ),
          child: Text(
            '$ward',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: selected ? tokens.surface : tokens.heading,
            ),
          ),
        ),
      ),
    );
  }
}
