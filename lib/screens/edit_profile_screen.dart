import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../models/citizen_avatar.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_citizen_avatar.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_text_field.dart';

/// Edits the name, username and optional phone shown on the citizen profile.
///
/// The username follows the seven-day rule enforced by
/// [AuthService.saveCitizenProfile]: until that window has passed the handle is
/// shown read-only with the date it unlocks.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.authService = const AuthService(),
    required this.initialName,
    required this.initialUsername,
    required this.initialPhone,
    this.usernameChangedAt,
    this.initialAvatarColor = CitizenAvatarColor.fallback,
  });

  final AuthService authService;
  final String initialName;
  final String initialUsername;
  final String initialPhone;
  final DateTime? usernameChangedAt;
  final CitizenAvatarColor initialAvatarColor;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;

  bool _saving = false;
  String? _error;
  late CitizenAvatarColor _avatarColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _avatarColor = widget.initialAvatarColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  DateTime? get _unlocksAt => widget.usernameChangedAt?.add(
    AuthService.usernameChangeInterval,
  );

  bool get _usernameLocked {
    final unlocksAt = _unlocksAt;
    return unlocksAt != null && DateTime.now().isBefore(unlocksAt);
  }

  int get _daysUntilUnlock {
    final unlocksAt = _unlocksAt;
    if (unlocksAt == null) return 0;
    final remaining = unlocksAt.difference(DateTime.now());
    return (remaining.inSeconds / Duration.secondsPerDay).ceil().clamp(0, 7);
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.authService.saveCitizenProfile(
        name: _nameController.text,
        username: _usernameController.text,
        phone: _phoneController.text,
        avatarColor: _avatarColor.key,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on UsernameUnavailable {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.usernameTaken;
      });
    } on UsernameCooldown catch (error) {
      if (!mounted) return;
      final days = (error.availableAt.difference(DateTime.now()).inSeconds /
              Duration.secondsPerDay)
          .ceil()
          .clamp(1, 7)
          .toString();
      setState(() {
        _saving = false;
        _error = context.l10n.usernameLocked(days);
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'We could not save your profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final strings = context.l10n;

    return Scaffold(
      body: NsBackground(
        ambientGlow: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(title: strings.profileEditTitle),
                      const SizedBox(height: 20),
                      Text(
                        strings.fullName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                          color: tokens.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      NsTextField(
                        controller: _nameController,
                        label: strings.fullName,
                        hint: 'Sita Sharma',
                        icon: Icons.person_rounded,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.name(value, strings: strings),
                        autofillHints: const [AutofillHints.name],
                        autofocus: true,
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 16),
                      NsTextField(
                        controller: _usernameController,
                        label: strings.username,
                        hint: strings.usernameHint,
                        icon: Icons.alternate_email_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.username(value, strings: strings),
                        autocorrect: false,
                        enabled: !_usernameLocked,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9._]'),
                          ),
                        ],
                        helper: _usernameLocked
                            ? strings.usernameLocked('$_daysUntilUnlock')
                            : strings.usernameChangeReady,
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 16),
                      NsTextField(
                        controller: _phoneController,
                        label: '${strings.phone} (${strings.optional})',
                        hint: '+977 98XXXXXXXX',
                        icon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        validator: (value) =>
                            Validators.optionalPhone(value, strings: strings),
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\-\s()]'),
                          ),
                        ],
                        helper: strings.signUpPhoneHelper,
                        onChanged: (_) => _clearError(),
                        onFieldSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        strings.avatarColor,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                          color: tokens.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AvatarColorPicker(
                        selected: _avatarColor,
                        initials: _initials,
                        onSelected: (color) {
                          HapticFeedback.selectionClick();
                          setState(() => _avatarColor = color);
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            key: const Key('edit-profile-error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: tokens.errorBorder,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      NsPrimaryButton(
                        key: const Key('edit-profile-save'),
                        label: strings.profileSetupSave,
                        icon: Icons.check_rounded,
                        isLoading: _saving,
                        onPressed: _save,
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

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  String get _initials {
    final parts = widget.initialName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NS';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// One tap picks the avatar colour; the initials preview updates with it.
class _AvatarColorPicker extends StatelessWidget {
  const _AvatarColorPicker({
    required this.selected,
    required this.initials,
    required this.onSelected,
  });

  final CitizenAvatarColor selected;
  final String initials;
  final ValueChanged<CitizenAvatarColor> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final color in CitizenAvatarColor.values)
          Semantics(
            button: true,
            selected: color == selected,
            label: '${color.key} avatar',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('avatar-color-${color.key}'),
                onTap: () => onSelected(color),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == selected
                          ? tokens.accentText
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: NsCitizenAvatar(
                    initials: initials,
                    color: color,
                    size: 38,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('edit-profile-back'),
            onTap: () => Navigator.of(context).pop(false),
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.surface,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.border, width: 1.4),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: tokens.heading,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: tokens.heading,
            ),
          ),
        ),
      ],
    );
  }
}
