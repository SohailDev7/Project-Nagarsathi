import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/citizen_avatar.dart';
import '../models/citizen_location.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_bottom_nav.dart';
import '../widgets/ns_citizen_avatar.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_ward_picker.dart';
import 'edit_profile_screen.dart';

/// The citizen's own profile, laid out like an Instagram profile: a handle bar,
/// an avatar beside the account stats, then the civic activity feed.
///
/// The bottom navigation stays visible, so leaving is a tab tap rather than a
/// back arrow.
class CitizenProfileScreen extends StatefulWidget {
  const CitizenProfileScreen({
    super.key,
    this.authService = const AuthService(),
    this.initialName,
    this.onOpenAccountMenu,
    this.onProfileChanged,
  });

  final AuthService authService;

  /// Value already loaded by the home screen, shown before Firestore replies.
  final String? initialName;

  /// Opens the account actions sheet (settings, sign out, delete profile).
  final VoidCallback? onOpenAccountMenu;

  /// Called with the new display name after a successful edit.
  final ValueChanged<String>? onProfileChanged;

  @override
  State<CitizenProfileScreen> createState() => _CitizenProfileScreenState();
}

class _CitizenProfileScreenState extends State<CitizenProfileScreen> {
  bool _loading = true;
  String? _name;
  String? _username;
  String? _phone;
  DateTime? _joinedAt;
  DateTime? _usernameChangedAt;
  CitizenLocation? _location;
  CitizenAvatarColor _avatarColor = CitizenAvatarColor.fallback;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName;
    _load();
  }

  Future<void> _load() async {
    var name = widget.initialName;
    String? username;
    String? phone;
    DateTime? joinedAt;
    DateTime? usernameChangedAt;
    CitizenLocation? location;
    var avatarColor = CitizenAvatarColor.fallback;

    if (AuthService.isConfigured) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userName = user?.displayName?.trim();
        if (name == null || name.isEmpty) name = userName;

        final profile = await widget.authService.loadCitizenProfile();
        if (profile != null) {
          final docName = (profile['name'] as String?)?.trim();
          if (docName != null && docName.isNotEmpty) name = docName;
          username = (profile['username'] as String?)?.trim();
          phone = (profile['phone'] as String?)?.trim();
          joinedAt = _readTimestamp(profile['createdAt']);
          usernameChangedAt = _readTimestamp(profile['usernameChangedAt']);
          location = CitizenLocation.tryFromMap(profile['location']);
          avatarColor = CitizenAvatarColor.fromKey(profile['avatarColor']);
        }
      } catch (_) {
        // Keep whatever the home screen already knew.
      }
    }

    if (!mounted) return;
    setState(() {
      _name = name;
      _username = username;
      _phone = phone;
      _joinedAt = joinedAt;
      _usernameChangedAt = usernameChangedAt;
      _location = location;
      _avatarColor = avatarColor;
      _loading = false;
    });
  }

  static DateTime? _readTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get _displayName {
    final name = _name?.trim();
    return (name == null || name.isEmpty) ? 'NagarSathi citizen' : name;
  }

  String get _handle {
    final username = _username?.trim();
    if (username == null || username.isEmpty) return '@citizen';
    return '@$username';
  }

  String get _initials {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NS';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _openEditProfile() async {
    HapticFeedback.selectionClick();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          authService: widget.authService,
          initialName: _name ?? '',
          initialUsername: _username ?? '',
          initialPhone: _phone ?? '',
          usernameChangedAt: _usernameChangedAt,
          initialAvatarColor: _avatarColor,
        ),
      ),
    );
    if (saved != true || !mounted) return;

    await _load();
    if (!mounted) return;
    widget.onProfileChanged?.call(_displayName);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.l10n.profileSaved)));
  }

  /// Lets the citizen correct their ward straight from the profile, instead of
  /// having to go back to the home screen first.
  Future<void> _changeWard() async {
    HapticFeedback.selectionClick();
    final picked = await showWardPicker(
      context,
      initialMunicipality: _location?.municipality,
    );
    if (picked == null || !mounted) return;

    final saved = await widget.authService.saveLocation(picked);
    if (!mounted) return;
    if (saved) setState(() => _location = picked);

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            !AuthService.isConfigured || saved
                ? context.l10n.wardSavedProfile
                : context.l10n.wardSyncFailed,
          ),
        ),
      );
  }

  /// Opens the native share sheet with a public link anyone can open.
  Future<void> _shareProfile() async {
    HapticFeedback.selectionClick();

    final username = _username?.trim() ?? '';
    final link = username.isEmpty ? '' : AuthService.profileLink(username);
    final ward = _location == null
        ? ''
        : ' · ${_location!.municipality} Ward ${_location!.ward}';
    final message = username.isEmpty
        ? '$_displayName · NagarSathi'
        : '$_displayName (@$username) on NagarSathi$ward\n$link';

    try {
      await SharePlus.instance.share(
        ShareParams(text: message, subject: 'NagarSathi profile'),
      );
    } catch (_) {
      // No share sheet (or a test harness): copying still works.
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(context.l10n.profileLinkCopied)));
    }
  }

  void _comingSoon() {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.comingSoon),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  void _onNavSelected(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).maybePop();
      case 3:
        break;
      default:
        _comingSoon();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Scaffold(
      bottomNavigationBar: NsBottomNav(
        activeIndex: 3,
        onSelect: _onNavSelected,
      ),
      body: NsBackground(
        ambientGlow: true,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileBar(
                      title: _handle,
                      onMenu: widget.onOpenAccountMenu,
                    ),
                    const SizedBox(height: 22),
                    _buildHeader(strings),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: NsPrimaryButton(
                            key: const Key('profile-edit'),
                            label: strings.editProfile,
                            icon: Icons.edit_rounded,
                            height: 46,
                            onPressed: _openEditProfile,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NsOutlineButton(
                            key: const Key('profile-share'),
                            label: strings.shareProfile,
                            icon: Icons.ios_share_rounded,
                            height: 46,
                            onPressed: _shareProfile,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.profileActivity,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: tokens.heading,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.grid_view_rounded,
                          size: 19,
                          color: tokens.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ActivityEmptyState(loading: _loading),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppStrings strings) {
    final tokens = NsColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NsCitizenAvatar(
          initials: _initials,
          color: _avatarColor,
          size: 92,
          showBadge: true,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stat(value: '0', label: strings.profileReports),
                  _Stat(
                    value: _location == null ? '—' : '${_location!.ward}',
                    label: strings.profileWard,
                  ),
                  _Stat(
                    value: _joinedAt == null ? '—' : '${_joinedAt!.year}',
                    label: strings.profileSince,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: tokens.heading,
                ),
              ),
              const SizedBox(height: 2),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('profile-ward'),
                  onTap: _changeWard,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 13,
                          color: tokens.accentText,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _location == null
                                ? strings.setYourLocation
                                : '${_location!.municipality} · '
                                      '${_location!.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_location_alt_outlined,
                          size: 13,
                          color: tokens.muted,
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
    );
  }
}

class _ProfileBar extends StatelessWidget {
  const _ProfileBar({required this.title, this.onMenu});

  final String title;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: tokens.heading,
              ),
            ),
          ),
          if (onMenu == null)
            const SizedBox(width: 40)
          else
            _CircleButton(
              key: const Key('profile-menu'),
              icon: Icons.more_horiz_rounded,
              onTap: onMenu!,
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

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
            border: Border.all(color: tokens.border, width: 1.4),
          ),
          child: Icon(icon, size: 20, color: tokens.heading),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: tokens.heading,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: tokens.mint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const NsMascot(
                      size: 50,
                      mood: NsMascotMood.curious,
                      look: Offset(0, 0.2),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.profileActivityEmptyTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: tokens.heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.profileActivityEmptyBody,
                  style: TextStyle(
                    fontSize: 12,
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
