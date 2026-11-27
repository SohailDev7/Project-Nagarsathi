import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'ns_primary_button.dart';
import 'ns_text_field.dart';

/// What the citizen chose in the first-login profile dialog.
class ProfileSetupResult {
  const ProfileSetupResult({required this.name, required this.rememberMe});

  final String name;

  /// "Remember me on this device", ticked by default.
  final bool rememberMe;
}

/// Collects the name, unique username and optional phone that the shortened
/// sign-up no longer asks for, plus the "Remember me" choice so first-time
/// citizens see one popup instead of two.
///
/// Returns the saved profile and preference, or `null` when nothing was saved.
/// The dialog cannot be dismissed with the back button or a tap outside it,
/// since the details are required.
Future<ProfileSetupResult?> showProfileSetupDialog({
  required BuildContext context,
  required Map<String, dynamic>? profile,
  AuthService authService = const AuthService(),
  VoidCallback? onSignOut,
  bool rememberMeDefault = true,
}) {
  return showDialog<ProfileSetupResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: _ProfileSetupDialog(
        profile: profile,
        authService: authService,
        onSignOut: onSignOut,
        rememberMeDefault: rememberMeDefault,
      ),
    ),
  );
}

class _ProfileSetupDialog extends StatefulWidget {
  const _ProfileSetupDialog({
    required this.profile,
    required this.authService,
    required this.rememberMeDefault,
    this.onSignOut,
  });

  final Map<String, dynamic>? profile;
  final AuthService authService;
  final bool rememberMeDefault;
  final VoidCallback? onSignOut;

  @override
  State<_ProfileSetupDialog> createState() => _ProfileSetupDialogState();
}

class _ProfileSetupDialogState extends State<_ProfileSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;

  bool _saving = false;
  bool _rememberMe = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rememberMe = widget.rememberMeDefault;
    _nameController = TextEditingController(
      text: (widget.profile?['name'] as String?)?.trim() ?? '',
    );
    _usernameController = TextEditingController(
      text: (widget.profile?['username'] as String?)?.trim() ?? '',
    );
    _phoneController = TextEditingController(
      text: (widget.profile?['phone'] as String?)?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

    final name = _nameController.text.trim();
    try {
      await widget.authService.saveCitizenProfile(
        name: name,
        username: _usernameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(ProfileSetupResult(name: name, rememberMe: _rememberMe));
    } on UsernameUnavailable {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.usernameTaken;
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

    return Dialog(
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NsTokens.cardRadius),
        side: BorderSide(color: tokens.border, width: NsTokens.borderWidth),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.badge_rounded, size: 40, color: tokens.accentText),
              const SizedBox(height: 10),
              Text(
                strings.profileSetupTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: tokens.heading,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.profileSetupSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: tokens.muted,
                ),
              ),
              const SizedBox(height: 18),
              NsTextField(
                controller: _nameController,
                label: strings.fullName,
                hint: 'Sita Sharma',
                icon: Icons.person_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.name(v, strings: strings),
                autofillHints: const [AutofillHints.name],
                autofocus: true,
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 13),
              NsTextField(
                controller: _usernameController,
                label: strings.username,
                hint: strings.usernameHint,
                icon: Icons.alternate_email_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.username(v, strings: strings),
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                ],
                helper: strings.usernameHelper,
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 13),
              NsTextField(
                controller: _phoneController,
                label: '${strings.phone} (${strings.optional})',
                hint: '+977 98XXXXXXXX',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.optionalPhone(v, strings: strings),
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                ],
                helper: strings.signUpPhoneHelper,
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('profile-setup-error'),
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
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Checkbox(
                        key: const Key('profile-setup-remember-me'),
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.rememberMe,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: tokens.heading,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strings.rememberMeHelper,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: tokens.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NsPrimaryButton(
                key: const Key('profile-setup-save'),
                label: strings.profileSetupSave,
                icon: Icons.check_rounded,
                isLoading: _saving,
                onPressed: _save,
              ),
              if (widget.onSignOut != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  key: const Key('profile-setup-sign-out'),
                  onPressed: _saving
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onSignOut?.call();
                        },
                  child: Text(
                    strings.profileSetupSignOut,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: tokens.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }
}
