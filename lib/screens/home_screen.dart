import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/citizen_location.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Citizen home. A community reporting feed with the four primary
/// destinations in a bottom bar; only Home is available for now.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.locationService = const LocationService()});

  /// Overridable for tests so the confirmation flow can run without the
  /// location plugin.
  final LocationService locationService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _updateService = UpdateService();

  String? _name;
  String? _email;
  String? _version;
  CitizenLocation? _location;
  bool _locating = false;
  bool _locationAsked = false;
  bool _checkingForUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadVersion();
    _restoreLocation();
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!AuthService.isConfigured) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final name = user.displayName?.trim();
      if (!mounted) return;
      setState(() {
        _name = (name == null || name.isEmpty) ? null : name;
        _email = user.email;
      });
    } catch (_) {
      // The header simply falls back to the friendly greeting.
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.buildNumber.isEmpty
            ? info.version
            : '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      // Version display is cosmetic; ignore failures (e.g. in tests).
    }
  }

  Future<void> _restoreLocation() async {
    final saved = await const AuthService().loadLocation();
    if (!mounted) return;
    if (saved != null) {
      setState(() => _location = saved);
      return;
    }

    // Offline demo mode has no profile to store the ward on (and widget tests
    // have no location plugins), so leave the pill as "Set your location".
    if (!AuthService.isConfigured) return;

    // First visit on this account: ask for permission, then confirm the ward.
    if (_locationAsked) return;
    _locationAsked = true;
    await _detectLocation();
  }

  Future<void> _detectLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    CitizenLocation? detected;
    try {
      detected = await widget.locationService.detect().timeout(
        const Duration(seconds: 30),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _locating = false);
      _showMessage('Finding your ward took too long. Please try again.');
      return;
    } on LocationFailure catch (error) {
      if (!mounted) return;
      setState(() => _locating = false);
      _showMessage(error.message);
      return;
    } catch (_) {
      // No platform plugin (widget tests) or an unexpected platform error.
      if (mounted) setState(() => _locating = false);
      return;
    }

    if (!mounted) return;
    setState(() => _locating = false);

    // The citizen dismissed the system permission prompt.
    if (detected == null) return;
    final location = detected;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmWardDialog(location: location),
    );
    if (!mounted) return;
    if (confirmed != true) {
      _showMessage('No problem. Tap the location pill to try again.');
      return;
    }

    setState(() => _location = location);
    final saved = await const AuthService().saveLocation(location);
    if (!mounted) return;

    if (!AuthService.isConfigured) {
      _showMessage('Ward saved for this session.');
    } else if (saved) {
      _showMessage('Ward saved to your profile.');
    } else {
      _showMessage("Couldn't sync your ward. Tap the location pill to retry.");
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdate) return;
    setState(() => _checkingForUpdate = true);

    try {
      final update = await _updateService.checkForUpdate(force: true);
      if (!mounted) return;

      if (update == null) {
        _showMessage('NagarSathi is up to date.');
        return;
      }

      await showUpdateDialog(
        context: context,
        update: update,
        service: _updateService,
      );
    } on UpdateException catch (error) {
      if (mounted) {
        _showMessage('Could not check for updates: ${error.message}');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not check for updates: $error');
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
  }

  String get _firstName {
    final name = _name?.trim();
    if (name == null || name.isEmpty) return 'neighbour';
    return name.split(RegExp(r'\s+')).first;
  }

  String get _initials {
    final name = _name?.trim();
    if (name == null || name.isEmpty) return 'NS';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  void _comingSoon() {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Feature coming soon.'),
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _showAccountSheet() async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NsColors.of(context).surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _AccountSheet(
        name: _name ?? 'NagarSathi citizen',
        email: _email ?? 'Offline demo account',
        initials: _initials,
        version: _version,
        onSignOut: () {
          Navigator.of(sheetContext).pop();
          _signOut();
        },
        checkingForUpdate: _checkingForUpdate,
        onCheckForUpdates: () {
          Navigator.of(sheetContext).pop();
          _checkForUpdates();
        },
        onOpenSettings: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await const AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _BottomNavBar(
        onHome: () {},
        onComingSoon: _comingSoon,
      ),
      body: NsBackground(
        child: SafeArea(
          bottom: false,
          child: NsEntrance(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 26),
                      _buildGreeting(),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _LocationPill(
                          label: _location?.label ?? 'Set your location',
                          locating: _locating,
                          onTap: _locating ? null : _detectLocation,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ReportHero(onTap: _comingSoon),
                      const SizedBox(height: 26),
                      const _SectionTitle('Report in one tap'),
                      const SizedBox(height: 12),
                      _CategoryRow(onTap: _comingSoon),
                      const SizedBox(height: 26),
                      _SectionTitle(
                        'Around you',
                        action: 'See all',
                        onAction: _comingSoon,
                      ),
                      const SizedBox(height: 12),
                      _ReportList(onTap: _comingSoon),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          _version == null
                              ? 'NagarSathi · your city, by your side'
                              : 'NagarSathi · version $_version',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: NsColors.of(context).muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        const NsLogo(size: 32, depth: 2),
        const SizedBox(width: 9),
        Text(
          'NagarSathi',
          style: TextStyle(
            fontSize: 16,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: tokens.heading,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          showDot: true,
          onTap: _comingSoon,
        ),
        const SizedBox(width: 8),
        _AvatarButton(
          key: const Key('home-avatar'),
          initials: _initials,
          onTap: _showAccountSheet,
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final tokens = NsColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Namaste, $_firstName',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: tokens.heading,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'What needs fixing in your city today?',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const NsMascot(
          size: 58,
          mood: NsMascotMood.happy,
          look: Offset(0, 0.4),
        ),
      ],
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({
    required this.label,
    required this.locating,
    required this.onTap,
  });

  final String label;
  final bool locating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.border, width: 1.5),
            boxShadow: [
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                locating
                    ? Icons.my_location_rounded
                    : Icons.location_on_rounded,
                size: 15,
                color: tokens.accentText,
              ),
              const SizedBox(width: 5),
              Text(
                locating ? 'Finding your ward…' : label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: tokens.heading,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: tokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The hero stays lime in both themes; the inner action flips to a dark
    // forest plate in dark mode so it reads like the login screen's surfaces.
    final actionFill = isDark ? const Color(0xFF163B2B) : tokens.surface;
    final actionBorder = isDark ? tokens.border : AppColors.forest;
    final actionInk = isDark ? tokens.accentBright : AppColors.forest;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? tokens.primaryStrong : AppColors.primaryDark,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : AppColors.primaryDark.withValues(alpha: 0.34),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_rounded, size: 13, color: AppColors.forest),
                SizedBox(width: 5),
                Text(
                  'COMMUNITY REPORTING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.forest,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Something broken nearby?',
            style: TextStyle(
              fontSize: 22,
              height: 1.12,
              fontWeight: FontWeight.w900,
              color: AppColors.forest,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Send a photo and a short note. It goes straight to the desk that '
            'fixes it.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: AppColors.forest.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 14),
          NsPressable(
            onTap: onTap,
            color: actionFill,
            borderColor: actionBorder,
            shadowColor: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : AppColors.forest.withValues(alpha: 0.22),
            radius: 14,
            depth: 3,
            child: SizedBox(
              height: 44,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 17, color: actionInk),
                    const SizedBox(width: 8),
                    Text(
                      'Report an issue',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: actionInk,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: actionInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.action, this.onAction});

  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: tokens.accentText,
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.onTap});

  final VoidCallback onTap;

  static const _categories = [
    (Icons.construction_rounded, 'Roads', AppColors.sun),
    (Icons.delete_outline_rounded, 'Garbage', AppColors.primary),
    (Icons.lightbulb_outline_rounded, 'Lights', AppColors.sky),
    (Icons.water_drop_outlined, 'Water', AppColors.sky),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _categories.length; index++) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: _CategoryTile(
              icon: _categories[index].$1,
              label: _categories[index].$2,
              tint: _categories[index].$3,
              onTap: onTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: isDark ? 0.22 : 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tint.withValues(alpha: isDark ? 0.55 : 0.4),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: isDark ? tokens.heading : AppColors.forest,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.onTap});

  final VoidCallback onTap;

  static const _reports = [
    (
      Icons.delete_outline_rounded,
      'Overflowing bin near the chowk',
      'Baneshwor · 2h ago',
      'In progress',
      NsChipTone.sky,
    ),
    (
      Icons.construction_rounded,
      'Pothole on the main road',
      'Maitighar · Yesterday',
      'Reported',
      NsChipTone.sun,
    ),
    (
      Icons.lightbulb_outline_rounded,
      'Streetlight out on the lane',
      'Ward 12 · 2 days ago',
      'Resolved',
      NsChipTone.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < _reports.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _ReportRow(
            icon: _reports[index].$1,
            title: _reports[index].$2,
            subtitle: _reports[index].$3,
            status: _reports[index].$4,
            tone: _reports[index].$5,
            onTap: onTap,
          ),
        ],
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final NsChipTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: tokens.border),
                ),
                child: Icon(icon, size: 19, color: tokens.heading),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              NsChip(label: status, tone: tone, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tokens.surface,
            shape: BoxShape.circle,
            border: Border.all(color: tokens.border, width: 1.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 19, color: tokens.heading),
              if (showDot)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: tokens.errorBorder,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.surface, width: 1.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({super.key, required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? tokens.mint : AppColors.forest,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.primary : AppColors.primaryLight,
              width: 2,
            ),
          ),
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? tokens.accentText : Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.onHome, required this.onComingSoon});

  final VoidCallback onHome;
  final VoidCallback onComingSoon;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Floating plate instead of a flat edge-to-edge strip: it picks up the
    // login screen's rounded, chunky surfaces and lifts off the dark page.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: tokens.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : tokens.shadow,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: true,
                onTap: onHome,
              ),
              _NavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: 'Reports',
                active: false,
                onTap: onComingSoon,
              ),
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: 'Map',
                active: false,
                onTap: onComingSoon,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                active: false,
                onTap: onComingSoon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? tokens.accentText : tokens.muted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active ? tokens.mint : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active
                            ? AppColors.primary.withValues(
                                alpha: isDark ? 0.65 : 0.4,
                              )
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      active ? (activeIcon ?? icon) : icon,
                      size: 21,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      color: color,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({
    required this.name,
    required this.email,
    required this.initials,
    required this.onSignOut,
    required this.onCheckForUpdates,
    required this.onOpenSettings,
    required this.checkingForUpdate,
    this.version,
  });

  final String name;
  final String email;
  final String initials;
  final String? version;
  final VoidCallback onSignOut;
  final VoidCallback onCheckForUpdates;
  final VoidCallback onOpenSettings;
  final bool checkingForUpdate;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? tokens.mint : AppColors.forest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors.primary
                          : AppColors.primaryLight,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? tokens.accentText : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: tokens.heading,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const NsChip(label: 'CITIZEN', compact: true),
              ],
            ),
            const SizedBox(height: 18),
            NsOutlineButton(
              label: checkingForUpdate
                  ? 'Checking for updates...'
                  : 'Check for updates',
              icon: Icons.system_update_rounded,
              onPressed: checkingForUpdate ? null : onCheckForUpdates,
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              key: const Key('open-settings'),
              label: 'Appearance',
              icon: Icons.palette_outlined,
              onPressed: onOpenSettings,
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              tone: NsOutlineTone.danger,
              onPressed: onSignOut,
            ),
            if (version != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Version $version',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks the citizen to confirm the ward detected from their location.
///
/// Tapping "Yes, that's me" returns `true`; "Not quite" returns `false`.
class _ConfirmWardDialog extends StatelessWidget {
  const _ConfirmWardDialog({required this.location});

  final CitizenLocation location;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Dialog(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: tokens.mint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 28,
                  color: tokens.accentText,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Are you from',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              location.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: tokens.heading,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              location.municipality,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "We used your phone's location. Reports you send will be routed "
              'to this ward office.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 20),
            NsPrimaryButton(
              label: "Yes, that's me",
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not quite'),
            ),
          ],
        ),
      ),
    );
  }
}
