import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_controller.dart';
import '../models/data_export_request.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/data_export_demo_service.dart';
import '../services/data_export_service.dart';
import '../services/session_service.dart';
import '../services/staff_auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_primary_button.dart';

/// Preferences for language, appearance, App Lock, and privacy data export.
///
/// The lock section is deliberately separate from the sign-in flow: a citizen
/// or staff member can enable or remove the device check without signing out,
/// as long as Remember me is on for this device.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.controller,
    this.languageController,
    this.sessionService = const SessionService(),
    this.biometricService,
    this.dataExportService,
  });

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? controller;
  final LanguageController? languageController;

  final SessionService sessionService;
  final BiometricService? biometricService;
  final DataExportService? dataExportService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late final BiometricService _biometrics =
      widget.biometricService ?? BiometricService();
  late final DataExportService _dataExportService =
      widget.dataExportService ?? DataExportService();
  late final DataExportDemoService _dataExportDemoService =
      const DataExportDemoService();

  ThemeController get _controller =>
      widget.controller ?? ThemeController.instance;
  LanguageController get _languageController =>
      widget.languageController ?? LanguageController.instance;

  BiometricAvailability? _availability;
  bool _appLockEnabled = false;
  bool _rememberMe = true;
  bool _securityLoading = true;
  bool _securityBusy = false;
  String? _securityError;

  /// Set when a staff member or super admin is signed in on this device; only
  /// they have a password that can be changed from here.
  StaffSession? _staffSession;

  DataExportRequest? _latestExport;
  String? _registeredEmail;
  bool _exportLoading = true;
  bool _exportBusy = false;
  bool _demoRunning = false;
  String? _exportError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSecurity();
    _loadExportState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh device security and export expiry state when returning to the app.
    if (state == AppLifecycleState.resumed) {
      if (!_securityBusy) _loadSecurity();
      if (!_exportBusy) _loadExportState();
    }
  }

  Future<void> _loadSecurity() async {
    final availabilityFuture = _biometrics.availability();
    final appLockFuture = widget.sessionService.loadAppLock();
    final rememberFuture = widget.sessionService.loadRememberMe();
    final staffSessionFuture = widget.sessionService.loadStaffSession();

    final availability = await availabilityFuture;
    final appLock = await appLockFuture;
    final rememberMe = await rememberFuture;
    final staffSession = await staffSessionFuture;
    if (!mounted) return;

    setState(() {
      _availability = availability;
      _appLockEnabled = appLock;
      _rememberMe = rememberMe;
      _staffSession = staffSession;
      _securityLoading = false;
    });
  }

  Future<void> _openChangePassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NsColors.of(context).surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed != true || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.staffPasswordChanged)));
  }

  Future<void> _setAppLock(bool next) async {
    if (_securityBusy) return;

    final availability = _availability;
    if (next && !_rememberMe) {
      _showSecurityMessage(
        'Turn on Remember me first: sign in again and choose Remember me.',
      );
      return;
    }
    if (next && (availability == null || !availability.isSupported)) {
      _showSecurityMessage(
        'Add a fingerprint, face scan, or screen lock PIN in your phone '
        'settings first.',
      );
      return;
    }

    setState(() {
      _securityBusy = true;
      _securityError = null;
    });

    // Turning the lock off is also a sensitive change, so ask the phone to
    // confirm the person at the device. If the phone has no lock at all there
    // is nothing to verify, and simply clearing the preference is safe.
    if (availability != null && availability.isSupported) {
      final outcome = await _biometrics.authenticate(
        reason: next
            ? 'Turn on app lock for NagarSathi'
            : 'Turn off app lock for NagarSathi',
      );
      if (!outcome.success) {
        if (!mounted) return;
        setState(() {
          _securityBusy = false;
          _securityError = outcome.message;
        });
        _showSecurityMessage(outcome.message ?? 'Could not verify it is you.');
        return;
      }
    }

    await widget.sessionService.saveAppLock(next);
    if (!mounted) return;
    setState(() {
      _securityBusy = false;
      _appLockEnabled = next;
    });
    _showSecurityMessage(
      next
          ? 'App lock is on. NagarSathi will ask for your device lock when it '
                'reopens.'
          : 'App lock is off. Remember me will open this device directly.',
    );
  }

  void _showSecurityMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
  }

  Future<void> _loadExportState() async {
    final latestFuture = _dataExportService.loadLatestExport();
    final emailFuture = _dataExportService.resolveRegisteredEmail();

    final latest = await latestFuture;
    final email = await emailFuture;
    if (!mounted) return;

    setState(() {
      _latestExport = latest;
      _registeredEmail = email;
      _exportLoading = false;
    });
  }

  Future<void> _requestDataExport() async {
    if (_exportBusy) return;
    setState(() {
      _exportBusy = true;
      _exportError = null;
    });

    final strings = AppStrings.forLocale(_languageController.value);
    try {
      final exportRequest = await _dataExportService.requestExport(
        locale: _languageController.value.code,
      );
      if (!mounted) return;
      setState(() {
        _exportBusy = false;
        _latestExport = exportRequest;
        _registeredEmail = exportRequest.email;
      });
      _showSecurityMessage(strings.dataExportSuccessMessage(exportRequest.email));
    } on DataExportFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _exportBusy = false;
        _exportError = error.message;
      });
      _showSecurityMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exportBusy = false;
        _exportError = strings.errUnknown;
      });
      _showSecurityMessage(strings.errUnknown);
    }
  }

  /// TEMPORARY DEMO: builds a real JSON + PDF package locally and shows the
  /// simulated emailed link and its 48-hour expiry, without the backend.
  Future<void> _runDemoExport() async {
    if (_demoRunning) return;
    setState(() => _demoRunning = true);
    try {
      final email =
          _registeredEmail ??
          await _dataExportService.resolveRegisteredEmail();
      final result = await _dataExportDemoService.run(
        email: email,
        locale: _languageController.value.code,
      );
      if (!mounted) return;
      setState(() {
        _demoRunning = false;
        _latestExport = result.request;
        _registeredEmail = result.request.email;
      });
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: NsColors.of(context).surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _DemoExportSheet(result: result),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _demoRunning = false);
      _showSecurityMessage('Could not build the demo export. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: _languageController,
      builder: (context, currentLocale, _) {
        final strings = AppStrings.forLocale(currentLocale);
        return Scaffold(
          appBar: AppBar(title: Text(strings.settingsTitle)),
          body: SafeArea(
            top: false,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: _controller,
              builder: (context, mode, _) {
                final tokens = NsColors.of(context);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    // ── Language Section ─────────────────────────────────────
                    Text(
                      strings.languageTitle,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.languageSubtitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LanguageOption(
                      locale: AppLocale.en,
                      icon: Icons.language_rounded,
                      title: 'English',
                      subtitle: strings.languageEnglishDesc,
                      selected: currentLocale.isEnglish,
                      onTap: () => _languageController.setLocale(AppLocale.en),
                    ),
                    const SizedBox(height: 12),
                    _LanguageOption(
                      locale: AppLocale.ne,
                      icon: Icons.translate_rounded,
                      title: 'नेपाली',
                      subtitle: strings.languageNepaliDesc,
                      selected: currentLocale.isNepali,
                      onTap: () => _languageController.setLocale(AppLocale.ne),
                    ),
                    const SizedBox(height: 32),

                    // ── Appearance / Theme Section ───────────────────────────
                    Text(
                      strings.themeTitle,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.themeSubtitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ThemeOption(
                      mode: ThemeMode.system,
                      icon: Icons.brightness_auto_rounded,
                      title: strings.themeSystem,
                      subtitle: strings.themeSystemDesc,
                      selected: mode == ThemeMode.system,
                      onTap: () => _controller.setMode(ThemeMode.system),
                    ),
                    const SizedBox(height: 12),
                    _ThemeOption(
                      mode: ThemeMode.light,
                      icon: Icons.light_mode_rounded,
                      title: strings.themeLight,
                      subtitle: strings.themeLightDesc,
                      selected: mode == ThemeMode.light,
                      onTap: () => _controller.setMode(ThemeMode.light),
                    ),
                    const SizedBox(height: 12),
                    _ThemeOption(
                      mode: ThemeMode.dark,
                      icon: Icons.dark_mode_rounded,
                      title: strings.themeDark,
                      subtitle: strings.themeDarkDesc,
                      selected: mode == ThemeMode.dark,
                      onTap: () => _controller.setMode(ThemeMode.dark),
                    ),
                    const SizedBox(height: 8),
                    const _ThemePreview(),
                    const SizedBox(height: 26),

                    // ── Security / App Lock Section ──────────────────────────
                    Text(
                      'Security',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'App Lock adds a checkpoint to Remember me so a saved '
                      'session only opens for you.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _AppLockCard(
                      availability: _availability,
                      enabled: _appLockEnabled,
                      rememberMe: _rememberMe,
                      loading: _securityLoading,
                      busy: _securityBusy,
                      error: _securityError,
                      onToggle: _setAppLock,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your face, fingerprint, and PIN are checked by your phone. '
                      'NagarSathi only receives a yes or no.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                    if (_staffSession != null) ...[
                      const SizedBox(height: 18),
                      NsOutlineButton(
                        key: const Key('settings-change-password'),
                        label: strings.staffChangePassword,
                        icon: Icons.lock_reset_rounded,
                        onPressed: _openChangePassword,
                      ),
                    ],
                    const SizedBox(height: 32),

                    // -- Privacy & Data Export Section ------------------------
                    Text(
                      strings.privacyTitle,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.privacySubtitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PrivacyExportCard(
                      strings: strings,
                      latestExport: _latestExport,
                      registeredEmail: _registeredEmail,
                      loading: _exportLoading,
                      busy: _exportBusy,
                      error: _exportError,
                      onDownloadMyData: _requestDataExport,
                      onRunDemo: _runDemoExport,
                      demoBusy: _demoRunning,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.dataExportFootnote,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.locale,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final AppLocale locale;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('language-mode-${locale.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? scheme.primary : tokens.border,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? tokens.mint : tokens.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected ? tokens.accentText : tokens.muted,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? scheme.primary : tokens.inputBorder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('theme-mode-${mode.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? scheme.primary : tokens.border,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? tokens.mint : tokens.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected ? tokens.accentText : tokens.muted,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? scheme.primary : tokens.inputBorder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLockCard extends StatelessWidget {
  const _AppLockCard({
    required this.availability,
    required this.enabled,
    required this.rememberMe,
    required this.loading,
    required this.busy,
    required this.error,
    required this.onToggle,
  });

  final BiometricAvailability? availability;
  final bool enabled;
  final bool rememberMe;
  final bool loading;
  final bool busy;
  final String? error;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final supported = availability?.isSupported ?? false;
    final canToggle = !loading && !busy && supported;
    final subtitle = _subtitle();
    final methodNames = availability?.methodSummary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: enabled ? scheme.primary : tokens.border,
          width: enabled ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled ? tokens.mint : tokens.surfaceSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  _glyph(),
                  size: 24,
                  color: enabled ? tokens.accentText : tokens.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'App lock',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: tokens.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (!loading && supported) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: enabled ? tokens.mint : tokens.surfaceSoft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: enabled
                                    ? scheme.primary.withValues(alpha: 0.4)
                                    : tokens.border,
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              enabled ? 'ON' : 'OFF',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                color: enabled
                                    ? tokens.accentText
                                    : tokens.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (loading || busy)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 20,
                    color: tokens.muted,
                  ),
                )
              else
                Switch.adaptive(
                  value: enabled,
                  onChanged: canToggle && (enabled || rememberMe)
                      ? onToggle
                      : null,
                  activeThumbColor: scheme.onPrimary,
                  activeTrackColor: scheme.primary,
                ),
            ],
          ),
          if (!loading && supported && methodNames != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: tokens.accentText,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Available: $methodNames',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!loading && !supported) ...[
            const SizedBox(height: 10),
            _InfoLine(
              icon: Icons.info_outline_rounded,
              color: tokens.errorBorder,
              text:
                  'No fingerprint, face scan, or screen lock PIN found. Add '
                  'one in your phone settings to use app lock.',
            ),
          ],
          if (!loading && supported && !rememberMe && !enabled) ...[
            const SizedBox(height: 10),
            _InfoLine(
              icon: Icons.lock_clock_rounded,
              color: tokens.muted,
              text:
                  'Turning this on needs Remember me. Sign in again and choose '
                  'Remember me, then come back here.',
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            _InfoLine(
              icon: Icons.error_outline_rounded,
              color: tokens.errorBorder,
              text: error!,
            ),
          ],
        ],
      ),
    );
  }

  String _subtitle() {
    if (loading) return 'Checking what this phone supports…';
    final availability = this.availability;
    if (availability == null || !availability.isSupported) {
      return 'Fingerprint, face scan, or screen lock PIN';
    }
    if (enabled) {
      return 'Ask for ${availability.methodSummary.toLowerCase()} when '
          'NagarSathi reopens.';
    }
    if (!rememberMe) {
      return 'Off • Needs Remember me on this device.';
    }
    return 'Off • Add a device check to a remembered session.';
  }

  IconData _glyph() {
    final availability = this.availability;
    if (availability == null || !availability.isSupported) {
      return Icons.lock_outline_rounded;
    }
    if (availability.hasFace) return Icons.face_rounded;
    if (availability.hasFingerprint) return Icons.fingerprint_rounded;
    if (availability.hasIris) return Icons.remove_red_eye_rounded;
    return Icons.pin_rounded;
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: tokens.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small live sample so the effect is visible without leaving the screen.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('theme-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PREVIEW',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: tokens.muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: tokens.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ward 3 · Jhamsikhel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: tokens.ink,
                        ),
                      ),
                      Text(
                        'Pothole reported 2h ago',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                        ),
                      ),
                    ],
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

/// Lets a signed-in staff member or super admin replace their password without
/// signing out. Both fields stay obscured; the same length rule as the forced
/// first-login change applies.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _staffAuth = const StaffAuthService();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final strings = context.l10n;
    final next = _newController.text;

    if (next.trim().length < 6) {
      setState(() => _error = strings.staffPasswordLengthError);
      return;
    }
    if (next != _confirmController.text) {
      setState(() => _error = strings.staffPasswordMismatch);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _staffAuth.updateStaffPassword(next);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not change the password. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.staffChangePassword,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.staffPasswordLengthHint,
            style: TextStyle(fontSize: 13, color: tokens.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('change-password-new'),
            controller: _newController,
            obscureText: true,
            enabled: !_busy,
            decoration: InputDecoration(labelText: strings.staffNewPassword),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('change-password-confirm'),
            controller: _confirmController,
            obscureText: true,
            enabled: !_busy,
            decoration: InputDecoration(labelText: strings.confirmPassword),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 20),
          NsPrimaryButton(
            label: strings.staffChangePassword,
            isLoading: _busy,
            onPressed: _submit,
            icon: Icons.lock_reset_rounded,
          ),
        ],
      ),
    );
  }
}

class _PrivacyExportCard extends StatelessWidget {
  const _PrivacyExportCard({
    required this.strings,
    required this.latestExport,
    required this.registeredEmail,
    required this.loading,
    required this.busy,
    required this.error,
    required this.onDownloadMyData,
    this.onRunDemo,
    this.demoBusy = false,
  });

  final AppStrings strings;
  final DataExportRequest? latestExport;
  final String? registeredEmail;
  final bool loading;
  final bool busy;
  final String? error;
  final VoidCallback onDownloadMyData;
  final VoidCallback? onRunDemo;
  final bool demoBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final export = latestExport;
    final isExpired = export != null && export.isExpiredAt();
    final hasActiveExport = export != null && !isExpired;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasActiveExport ? scheme.primary : tokens.border,
          width: hasActiveExport ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.mint,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.archive_rounded,
                  size: 23,
                  color: tokens.accentText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            strings.dataExportCardTitle,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: tokens.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (export != null) ...[
                          const SizedBox(width: 8),
                          _ExportStatusBadge(
                            strings: strings,
                            export: export,
                            isExpired: isExpired,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      strings.dataExportCardDesc,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.data_object_rounded,
            color: tokens.accentText,
            text: strings.dataExportFormatsLine,
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.mark_email_read_rounded,
            color: tokens.accentText,
            text: registeredEmail != null && registeredEmail!.isNotEmpty
                ? '${strings.dataExportDeliveryLine} ($registeredEmail)'
                : strings.dataExportDeliveryLine,
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.timer_outlined,
            color: tokens.muted,
            text: strings.dataExportExpiryLine,
          ),
          if (!loading && export != null) ...[
            const SizedBox(height: 12),
            _ExportSummaryBox(
              strings: strings,
              export: export,
              isExpired: isExpired,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.error_outline_rounded,
              color: tokens.errorBorder,
              text: error!,
            ),
          ],
          const SizedBox(height: 14),
          NsPrimaryButton(
            key: const Key('download-my-data-button'),
            label: strings.downloadMyData,
            icon: Icons.download_rounded,
            isLoading: busy,
            onPressed: busy ? null : onDownloadMyData,
          ),
          if (onRunDemo != null) ...[
            const SizedBox(height: 10),
            Material(
              color: tokens.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const Key('download-my-data-demo-button'),
                onTap: demoBusy ? null : onRunDemo,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 18,
                        color: tokens.accentText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              demoBusy
                                  ? 'Generating demo package…'
                                  : 'Demo: run export now',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: tokens.ink,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Temporary preview - sample data, no email',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: tokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (demoBusy)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              tokens.accentText,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: tokens.muted,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportStatusBadge extends StatelessWidget {
  const _ExportStatusBadge({
    required this.strings,
    required this.export,
    required this.isExpired,
  });

  final AppStrings strings;
  final DataExportRequest export;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    final label = isExpired
        ? strings.dataExportExpiredBadge
        : export.status == DataExportStatus.sent
        ? strings.dataExportEmailSentBadge
        : strings.dataExportRequestedBadge;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isExpired ? tokens.surfaceSoft : tokens.mint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isExpired
              ? tokens.errorBorder
              : scheme.primary.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: isExpired ? scheme.error : tokens.accentText,
        ),
      ),
    );
  }
}

class _ExportSummaryBox extends StatelessWidget {
  const _ExportSummaryBox({
    required this.strings,
    required this.export,
    required this.isExpired,
  });

  final AppStrings strings;
  final DataExportRequest export;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final remaining = export.remainingAt();
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);

    return Container(
      key: const Key('data-export-summary-box'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.dataExportSentTo(export.email),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isExpired
                ? strings.dataExportExpiredNotice
                : strings.dataExportExpiresIn(hours, minutes),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isExpired
                  ? Theme.of(context).colorScheme.error
                  : tokens.accentText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            strings.dataExportCounts(export.reportCount, export.commentCount),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// TEMPORARY DEMO ONLY: shows a generated export package and the simulated
/// emailed download link with its 48-hour expiry, for reviewing the feature.
class _DemoExportSheet extends StatelessWidget {
  const _DemoExportSheet({required this.result});

  final DataExportDemoResult result;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final request = result.request;
    final remaining = request.remainingAt();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.mint,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'DEMO PREVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                      color: tokens.accentText,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _clock(request.requestedAt),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Export package ready',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${request.reportCount} reports and ${request.commentCount} '
              'comments were packed for ${request.email}.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: tokens.muted,
              ),
            ),
            const SizedBox(height: 16),
            _DemoStep(
              icon: Icons.check_circle_rounded,
              title: '1. Request received',
              detail:
                  'Export ${request.exportId} created securely for your account.',
            ),
            _DemoStep(
              icon: Icons.description_rounded,
              title: '2. Package generated',
              detail:
                  'JSON ${_kb(result.jsonBytes)} - machine readable\n'
                  'PDF ${_kb(result.pdfBytes)} - human readable',
            ),
            _DemoStep(
              icon: Icons.email_rounded,
              title: '3. Link emailed',
              detail:
                  'Delivered ${_elapsed(result.deliveredAfter)} after the '
                  'request (SLA ${request.deliverySlaMinutes} min).',
            ),
            _DemoStep(
              icon: Icons.timer_outlined,
              title: '4. Link expires in 48 hours',
              detail:
                  'Expires ${_clock(request.expiresAt)} - about '
                  '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m '
                  'left. After that the link stops working.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECURE DOWNLOAD LINK',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                      color: tokens.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    result.secureLink,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            NsPrimaryButton(
              key: const Key('demo-open-pdf-button'),
              label: 'Open PDF',
              icon: Icons.picture_as_pdf_rounded,
              onPressed: () => _open(context, result.pdfPath),
            ),
            const SizedBox(height: 10),
            NsOutlineButton(
              key: const Key('demo-open-json-button'),
              label: 'Open JSON',
              icon: Icons.data_object_rounded,
              onPressed: () => _open(context, result.jsonPath),
            ),
            const SizedBox(height: 10),
            NsOutlineButton(
              key: const Key('demo-copy-link-button'),
              label: 'Copy secure link',
              icon: Icons.link_rounded,
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: result.secureLink),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo link copied.')),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Demo only: no real email was sent and this link is simulated. '
              'The JSON and PDF files above were really generated by the same '
              'code the production export uses.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: tokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String path) async {
    final result = await OpenFilex.open(path);
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}\n$path')),
      );
    }
  }

  static String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';

  static String _elapsed(Duration duration) {
    if (duration.inSeconds < 60) return '${duration.inSeconds}s';
    return '${duration.inMinutes}m';
  }

  static String _clock(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.day}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _DemoStep extends StatelessWidget {
  const _DemoStep({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tokens.accentText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
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
