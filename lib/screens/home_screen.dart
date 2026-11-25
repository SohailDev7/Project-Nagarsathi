import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/citizen_location.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_app_lock_prompt.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_remember_me_notification.dart';
import '../widgets/ns_rotating_line.dart';
import '../widgets/ns_route.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Citizen home. A community reporting feed with the four primary
/// destinations in a bottom bar; only Home is available for now.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.locationService = const LocationService(),
    this.initialName,
    this.initialEmail,
    this.showRememberMePrompt = false,
  });

  /// Overridable for tests so the confirmation flow can run without the
  /// location plugin.
  final LocationService locationService;
  final String? initialName;
  final String? initialEmail;
  final bool showRememberMePrompt;

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
    _name = widget.initialName;
    _email = widget.initialEmail;
    _loadProfile();
    _loadVersion();
    _restoreLocation();
    if (widget.showRememberMePrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybePromptRememberMe();
      });
    }
  }

  Future<void> _maybePromptRememberMe() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final remembered = await showRememberMeNotification(
      context: context,
      isStaff: false,
    );
    if (!mounted || remembered != true) return;

    // Remember me is now on. Offer the device-lock layer while the choice is
    // still fresh, but never insist: a user can enable it later in Settings.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await showAppLockOffer(context: context);
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!AuthService.isConfigured && widget.initialName == null) return;
    try {
      String? cachedName;
      String? cachedEmail;
      try {
        final prefs = await SharedPreferences.getInstance();
        cachedName = prefs.getString('cached_display_name');
        cachedEmail = prefs.getString('cached_email');
      } catch (_) {}

      final user = FirebaseAuth.instance.currentUser;
      var name =
          widget.initialName ??
          _name ??
          cachedName ??
          user?.displayName?.trim();
      var email =
          widget.initialEmail ?? _email ?? cachedEmail ?? user?.email?.trim();

      if (user != null) {
        if (name == null || name.isEmpty) {
          try {
            await user.reload();
            name = FirebaseAuth.instance.currentUser?.displayName?.trim();
          } catch (_) {}
        }

        if (name == null || name.isEmpty || email == null || email.isEmpty) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            final data = doc.data();
            final docName = data?['name'] as String?;
            if (docName != null && docName.trim().isNotEmpty) {
              name = docName.trim();
            }
            final docEmail = data?['email'] as String?;
            if (docEmail != null && docEmail.trim().isNotEmpty) {
              email = docEmail.trim();
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      if (name != null && name.isNotEmpty) {
        setState(() {
          _name = name;
          if (email != null && email.isNotEmpty) _email = email;
        });
      }
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
      _showMessage(context.l10n.locationTimeout);
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
      _showMessage(context.l10n.wardNotConfirmed);
      return;
    }

    setState(() => _location = location);
    final saved = await const AuthService().saveLocation(location);
    if (!mounted) return;

    final strings = context.l10n;
    if (!AuthService.isConfigured) {
      _showMessage(strings.wardSavedSession);
    } else if (saved) {
      _showMessage(strings.wardSavedProfile);
    } else {
      _showMessage(strings.wardSyncFailed);
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
        _showMessage(context.l10n.upToDate);
        return;
      }

      await showUpdateDialog(
        context: context,
        update: update,
        service: _updateService,
      );
    } on UpdateException catch (error) {
      if (mounted) {
        _showMessage(context.l10n.updateCheckFailed(error.message));
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context.l10n.updateCheckFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
  }

  String get _firstName {
    final name = _name?.trim();
    if (name == null || name.isEmpty) return context.l10n.neighbour;
    return name.split(RegExp(r'\s+')).first;
  }

  String get _initials {
    final name = _name?.trim();
    if (name == null || name.isEmpty || name == 'NagarSathi citizen') {
      return 'NS';
    }
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
      SnackBar(
        content: Text(context.l10n.comingSoon),
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _showAccountSheet() async {
    HapticFeedback.selectionClick();
    await _loadProfile();
    if (!mounted) return;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase Auth is not available in local/widget tests.
    }
    final displayName = (_name != null && _name!.trim().isNotEmpty)
        ? _name!.trim()
        : (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!.trim()
              : 'NagarSathi citizen');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: NsColors.of(context).surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _AccountSheet(
        name: displayName,
        email: context.l10n.citizenAccount,
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
            NsPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await const AuthService().signOut();
    await const SessionService().saveRememberMe(false);
    await const SessionService().saveAppLock(false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      NsPageRoute<void>(
        style: NsTransitionStyle.fade,
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Scaffold(
      bottomNavigationBar: _BottomNavBar(
        onHome: () {},
        onComingSoon: _comingSoon,
        onProfile: _showAccountSheet,
      ),
      body: NsBackground(
        ambientGlow: true,
        child: SafeArea(
          bottom: false,
          child: NsEntrance(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
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
                          label: _location?.label ?? strings.setYourLocation,
                          locating: _locating,
                          onTap: _locating ? null : _detectLocation,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ReportHero(onTap: _comingSoon),
                      const SizedBox(height: 26),
                      _SectionTitle(strings.reportInOneTap),
                      const SizedBox(height: 12),
                      _CategoryRow(onTap: _comingSoon),
                      const SizedBox(height: 26),
                      _SectionTitle(
                        strings.aroundYou,
                        action: strings.seeAll,
                        onAction: _comingSoon,
                      ),
                      const SizedBox(height: 12),
                      _ReportList(onTap: _comingSoon),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          _version == null
                              ? strings.appTagline
                              : strings.versionText(_version!),
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
        const NsLogo(size: 32, depth: 0),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'NagarSathi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16.5,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
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
    final strings = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.greeting(_firstName),
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
              NsRotatingLine(
                lines: strings.homeTips,
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1D3429)
                : const Color(0xFF1E7B4B),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.primaryLight.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: const NsMascot(
            size: 52,
            mood: NsMascotMood.happy,
            look: Offset(0, 0.4),
          ),
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
          padding: const EdgeInsets.fromLTRB(7, 6, 10, 6),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tokens.mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  locating
                      ? Icons.my_location_rounded
                      : Icons.location_on_rounded,
                  size: 13.5,
                  color: tokens.accentText,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  locating ? context.l10n.findingYourWard : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: tokens.heading,
                  ),
                ),
              ),
              const SizedBox(width: 3),
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
    final strings = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Deep forest action plate pops crisply over the vibrant lime hero card
    // in both light and dark modes with zero white glare.
    const actionFill = Color(0xFF163B2B);
    final actionInk = isDark ? tokens.accentBright : const Color(0xFFA5F542);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6AD90E), AppColors.primary, Color(0xFF4BB800)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark
              ? AppColors.primaryLight.withValues(alpha: 0.35)
              : AppColors.primaryDark.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.42)
                : AppColors.primary.withValues(alpha: 0.28),
            offset: const Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -36,
            width: 140,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBEE2B2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.campaign_rounded,
                        size: 13,
                        color: AppColors.forest,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        strings.communityReporting,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.forest,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  strings.somethingBrokenNearby,
                  style: const TextStyle(
                    fontSize: 22.5,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.forest,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.reportHeroPrompt,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                NsPressable(
                  onTap: onTap,
                  color: actionFill,
                  borderColor: isDark
                      ? tokens.border
                      : Colors.white.withValues(alpha: 0.6),
                  shadowColor: isDark
                      ? Colors.black.withValues(alpha: 0.45)
                      : AppColors.forest.withValues(alpha: 0.16),
                  radius: 15,
                  depth: 0,
                  child: SizedBox(
                    height: 46,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            size: 17,
                            color: actionInk,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            strings.reportNow,
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

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final categories = [
      (Icons.construction_rounded, strings.categoryRoads, AppColors.sun),
      (
        Icons.delete_outline_rounded,
        strings.categoryGarbage,
        AppColors.primary,
      ),
      (Icons.lightbulb_outline_rounded, strings.categoryLights, AppColors.sky),
      (Icons.water_drop_outlined, strings.categoryWaterHero, AppColors.sky),
    ];

    return Row(
      children: [
        for (var index = 0; index < categories.length; index++) ...[
          if (index > 0) const SizedBox(width: 9),
          Expanded(
            child: _CategoryTile(
              icon: categories[index].$1,
              label: categories[index].$2,
              tint: categories[index].$3,
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          decoration: BoxDecoration(
            color: isDark
                ? tokens.surface
                : Color.alphaBlend(tint.withValues(alpha: 0.28), tokens.surface),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? tokens.border.withValues(alpha: 0.85)
                  : tint.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
                offset: const Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: isDark ? 0.22 : 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19.5,
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

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final reports = [
      (
        Icons.delete_outline_rounded,
        strings.reportOverflowBin,
        strings.reportOverflowBinMeta,
        strings.statusInProgress,
        NsChipTone.sky,
      ),
      (
        Icons.construction_rounded,
        strings.reportPotholeTitle,
        strings.reportPotholeMeta,
        strings.statusReported,
        NsChipTone.sun,
      ),
      (
        Icons.lightbulb_outline_rounded,
        strings.reportStreetlightTitle,
        strings.reportStreetlightMeta,
        strings.statusResolved,
        NsChipTone.green,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < reports.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _ReportRow(
            icon: reports[index].$1,
            title: reports[index].$2,
            subtitle: reports[index].$3,
            status: reports[index].$4,
            tone: reports[index].$5,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
                offset: const Offset(0, 5),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19.5, color: tokens.heading),
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
              color: isDark ? tokens.accentText : const Color(0xFFEAF7E2),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.onHome,
    required this.onComingSoon,
    required this.onProfile,
  });

  final VoidCallback onHome;
  final VoidCallback onComingSoon;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
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
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: tokens.border.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.08),
                offset: const Offset(0, 8),
                blurRadius: 22,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: strings.navHome,
                active: true,
                onTap: onHome,
              ),
              _NavItem(
                icon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
                label: strings.navReports,
                active: false,
                onTap: onComingSoon,
              ),
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                label: strings.navMap,
                active: false,
                onTap: onComingSoon,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: strings.navProfile,
                active: false,
                onTap: onProfile,
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
    final strings = context.l10n;
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
                      color: isDark
                          ? tokens.accentText
                          : const Color(0xFFEAF7E2),
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
                NsChip(label: strings.citizenBadge, compact: true),
              ],
            ),
            const SizedBox(height: 18),
            NsOutlineButton(
              label: checkingForUpdate
                  ? '${strings.checkForUpdates}…'
                  : strings.checkForUpdates,
              icon: Icons.system_update_rounded,
              onPressed: checkingForUpdate ? null : onCheckForUpdates,
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              key: const Key('open-settings'),
              label: strings.settings,
              icon: Icons.tune_rounded,
              onPressed: onOpenSettings,
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              label: strings.signOut,
              icon: Icons.logout_rounded,
              tone: NsOutlineTone.danger,
              onPressed: onSignOut,
            ),
            if (version != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  strings.versionText(version!),
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
    final strings = context.l10n;

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
              strings.areYouFrom,
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
              strings.phoneLocationNotice,
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
              label: strings.yesThatsMe,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.notQuite),
            ),
          ],
        ),
      ),
    );
  }
}
