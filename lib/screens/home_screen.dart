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
import '../widgets/ns_bottom_nav.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_pressable.dart';
import '../widgets/ns_profile_setup_dialog.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_remember_me_notification.dart';
import '../widgets/ns_rotating_line.dart';
import '../widgets/ns_route.dart';
import '../widgets/update_dialog.dart';
import 'citizen_profile_screen.dart';
import 'delete_profile_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Citizen home. A community reporting feed with the four primary
/// destinations in a bottom bar; only Home is available for now.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.locationService = const LocationService(),
    this.authService = const AuthService(),
    this.initialName,
    this.initialEmail,
    this.showRememberMePrompt = false,
  });

  /// Overridable for tests so the confirmation flow can run without the
  /// location plugin.
  final LocationService locationService;
  final AuthService authService;
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

  /// Set once the profile dialog has answered the remember-me question, so the
  /// standalone remember-me popup is not shown a second time.
  bool _rememberAnsweredInProfile = false;
  bool _rememberFromProfile = false;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName;
    _email = widget.initialEmail;
    _loadProfile();
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeCompleteProfile();
      if (!mounted) return;

      // Citizens who did not see the profile dialog are asked about remembering
      // right away; waiting behind the ward prompt made the notification feel
      // like it arrived late.
      if (widget.showRememberMePrompt && !_rememberAnsweredInProfile) {
        await _maybePromptRememberMe();
        if (!mounted) return;
      }

      // Ask for the ward only once the profile is done, so the system location
      // prompt never appears behind a dialog.
      await _restoreLocation();
      if (!mounted || !widget.showRememberMePrompt) return;
      if (_rememberAnsweredInProfile && _rememberFromProfile) {
        await _offerAppLock();
      }
    });
  }

  /// Asks brand-new citizens (and anyone who signed in before the profile
  /// step existed) for the name, unique username and optional phone that the
  /// shortened sign-up no longer collects.
  Future<void> _maybeCompleteProfile() async {
    if (!AuthService.isConfigured) return;

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      return;
    }
    if (user == null) return;

    final Map<String, dynamic>? profile;
    try {
      profile = await const AuthService().loadCitizenProfile();
    } catch (_) {
      // Network or rules failure: do not block the citizen behind a form we
      // cannot save.
      return;
    }
    if (!mounted) return;

    final name = (profile?['name'] as String?)?.trim() ?? '';
    final username = (profile?['username'] as String?)?.trim() ?? '';
    if (name.isNotEmpty && username.isNotEmpty) return;

    final result = await showProfileSetupDialog(
      context: context,
      profile: profile,
      onSignOut: _signOut,
    );
    if (!mounted || result == null || result.name.isEmpty) return;

    // First-time citizens choose "Remember me" inside this same dialog, so
    // persist it here and keep the separate popup from appearing.
    _rememberAnsweredInProfile = true;
    _rememberFromProfile = result.rememberMe;
    await const SessionService().saveRememberMe(result.rememberMe);
    if (!result.rememberMe) {
      await const SessionService().saveAppLock(false);
    }

    if (!mounted) return;
    setState(() => _name = result.name);
  }

  /// Offers to protect the remembered session with the device lock once the
  /// profile dialog (or the remember-me popup) has enabled remembering.
  Future<void> _offerAppLock() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await showAppLockOffer(context: context);
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
    await _offerAppLock();
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
      // Never leave the citizen stuck: let them pick the ward by hand.
      await _offerWardPicker();
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
      await _offerWardPicker(initialMunicipality: location.municipality);
      return;
    }

    await _applyLocation(location);
  }

  /// Saves a confirmed or hand-picked ward and reports the outcome.
  Future<void> _applyLocation(CitizenLocation location) async {
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

  /// Manual fallback for reverse geocoders that omit the ward name, which is
  /// common on Nepali addresses. The citizen picks their ward and it is saved
  /// exactly like a detected one.
  Future<void> _offerWardPicker({String? initialMunicipality}) async {
    final picked = await showModalBottomSheet<CitizenLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WardPickerSheet(
        initialMunicipality: initialMunicipality ?? _location?.municipality,
      ),
    );
    if (picked == null || !mounted) return;
    await _applyLocation(picked);
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

  void _onNavSelected(int index) {
    switch (index) {
      case 0:
        break;
      case 3:
        _openProfile();
      default:
        _comingSoon();
    }
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

  Future<void> _openProfile() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      NsPageRoute<void>(
        builder: (_) => CitizenProfileScreen(
          initialName: _name,
          onOpenAccountMenu: _showAccountSheet,
          onProfileChanged: (name) {
            if (mounted) setState(() => _name = name);
          },
        ),
      ),
    );
    if (!mounted) return;
    await _loadProfile();
  }

  Future<void> _showAccountSheet() async {
    HapticFeedback.selectionClick();
    await _loadProfile();
    if (!mounted) return;

    User? user;
    try {
      if (AuthService.isConfigured) {
        user = FirebaseAuth.instance.currentUser;
      }
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
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
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
        onDeleteProfile: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  DeleteProfileScreen(authService: widget.authService),
            ),
          );
        },
        checkingForUpdate: _checkingForUpdate,
        onCheckForUpdates: () {
          Navigator.of(sheetContext).pop();
          _checkForUpdates();
        },
        onOpenSettings: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context)
              .push(NsPageRoute<void>(builder: (_) => const SettingsScreen()));
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();
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
      bottomNavigationBar: NsBottomNav(
        activeIndex: 0,
        onSelect: _onNavSelected,
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
                ? tokens.mint
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
            mood: NsMascotMood.excited,
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
                    color: AppColors.mint,
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
            color: Color.alphaBlend(
              tint.withValues(alpha: isDark ? 0.12 : 0.28),
              tokens.surface,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: tint.withValues(alpha: isDark ? 0.42 : 0.6),
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
                  color: tint.withValues(alpha: isDark ? 0.30 : 0.24),
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

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({
    required this.name,
    required this.email,
    required this.initials,
    required this.onSignOut,
    required this.onDeleteProfile,
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
  final VoidCallback onDeleteProfile;
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
      child: SingleChildScrollView(
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
            const SizedBox(height: 12),
            NsOutlineButton(
              key: const Key('delete-my-profile'),
              label: 'Delete my profile',
              icon: Icons.person_remove_outlined,
              tone: NsOutlineTone.danger,
              onPressed: onDeleteProfile,
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

/// Lets a citizen pick their ward when the phone's geocoder gives no ward.
///
/// Only KMC and LMC are served by the app, so the sheet offers their official
/// ward counts. The returned location uses the municipality's centre as its
/// coordinate, because the citizen's own GPS fix was never usable here.
class _WardPickerSheet extends StatefulWidget {
  const _WardPickerSheet({this.initialMunicipality});

  final String? initialMunicipality;

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
    Navigator.of(context).pop(
      CitizenLocation(
        latitude: _municipality.latitude,
        longitude: _municipality.longitude,
        municipality: _municipality.name,
        ward: ward,
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
                          'ward-picker-${_municipalities[index].code.toLowerCase()}',
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
                      final columns = 6;
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
