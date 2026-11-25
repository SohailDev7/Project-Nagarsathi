import 'package:material_ui/material_ui.dart';

import '../services/biometric_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Preferences for appearance and App Lock.
///
/// The lock section is deliberately separate from the sign-in flow: a citizen
/// can enable or remove the device check without signing out, as long as
/// Remember me is on for this device.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.controller,
    this.sessionService = const SessionService(),
    this.biometricService,
  });

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? controller;

  final SessionService sessionService;
  final BiometricService? biometricService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  late final BiometricService _biometrics =
      widget.biometricService ?? BiometricService();

  ThemeController get _controller =>
      widget.controller ?? ThemeController.instance;

  BiometricAvailability? _availability;
  bool _appLockEnabled = false;
  bool _rememberMe = true;
  bool _securityLoading = true;
  bool _securityBusy = false;
  String? _securityError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh device security options when returning from phone Settings.
    if (state == AppLifecycleState.resumed && !_securityBusy) {
      _loadSecurity();
    }
  }

  Future<void> _loadSecurity() async {
    final availabilityFuture = _biometrics.availability();
    final appLockFuture = widget.sessionService.loadAppLock();
    final rememberFuture = widget.sessionService.loadRememberMe();

    final availability = await availabilityFuture;
    final appLock = await appLockFuture;
    final rememberMe = await rememberFuture;
    if (!mounted) return;

    setState(() {
      _availability = availability;
      _appLockEnabled = appLock;
      _rememberMe = rememberMe;
      _securityLoading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _controller,
          builder: (context, mode, _) {
            final tokens = NsColors.of(context);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                Text(
                  'Theme',
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
                  'Choose how NagarSathi looks. System follows your device '
                  'setting automatically.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 18),
                for (final option in _options) ...[
                  _ThemeOption(
                    mode: option.mode,
                    icon: option.icon,
                    title: option.title,
                    subtitle: option.subtitle,
                    selected: mode == option.mode,
                    onTap: () => _controller.setMode(option.mode),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                const _ThemePreview(),
                const SizedBox(height: 26),
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThemeOptionData {
  const _ThemeOptionData({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
}

const _options = <_ThemeOptionData>[
  _ThemeOptionData(
    mode: ThemeMode.system,
    icon: Icons.brightness_auto_rounded,
    title: 'System',
    subtitle: 'Match your device setting',
  ),
  _ThemeOptionData(
    mode: ThemeMode.light,
    icon: Icons.light_mode_rounded,
    title: 'Light',
    subtitle: 'Warm cream background',
  ),
  _ThemeOptionData(
    mode: ThemeMode.dark,
    icon: Icons.dark_mode_rounded,
    title: 'Dark',
    subtitle: 'Easier on the eyes at night',
  ),
];

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
                  color: tokens.accentText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ward 16 · Kathmandu',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                ),
                Text(
                  'Muted',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Primary action',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.mint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.border),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: tokens.accentText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
