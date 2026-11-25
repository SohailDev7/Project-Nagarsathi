import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_auth_controls.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_shake.dart';
import '../widgets/ns_speech_bubble.dart';
import '../widgets/ns_split_hero_scaffold.dart';
import '../widgets/ns_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _shakeController = NsShakeController();

  bool _isLoading = false;
  bool _sent = false;
  bool _celebrating = false;
  bool _showError = false;
  bool _focused = false;
  String? _errorMessage;
  IdentifierKind _kind = IdentifierKind.empty;

  String get _contact => _identifierController.text.trim();

  @override
  void dispose() {
    _identifierController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  NsMascotMood get _mood {
    if (_sent) return NsMascotMood.celebrate;
    if (_showError) return NsMascotMood.sad;
    if (_focused) return NsMascotMood.curious;
    return NsMascotMood.happy;
  }

  String get _message {
    if (_sent) return 'Sent! Check your inbox in a moment.';
    if (_showError) {
      return _errorMessage ?? 'I need an email or phone number first.';
    }
    if (_isLoading) return 'Sending the reset link…';
    if (_focused) return 'Email or phone — either one works.';
    return 'Forgot it? Happens to everyone.';
  }

  void _onChanged(String value) {
    final kind = Validators.identifierKind(value);
    if (kind != _kind || _showError) {
      setState(() {
        _kind = kind;
        _showError = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _sendInstructions() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      _shakeController.shake();
      setState(() => _showError = true);
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await const AuthService().sendPasswordReset(_contact);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _shakeController.shake();
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _sent = true;
      _celebrating = true;
    });
    HapticFeedback.mediumImpact();
  }

  void _backToSignIn() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NsSplitHeroScaffold(
          topBar: Row(
            children: [
              NsBackButton(onPressed: _backToSignIn, onDarkHeader: true),
              const SizedBox(width: 10),
              const NsLogo(size: 30, depth: 0),
              const SizedBox(width: 8),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NagarSathi',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const NsAuthPreferencePills(onDarkHeader: true),
            ],
          ),
          hero: _buildHero(),
          sheetChild: NsEntrance(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(_sent),
                child: _sent ? _buildSuccess() : _buildForm(),
              ),
            ),
          ),
        ),
        if (_celebrating)
          Positioned.fill(
            child: NsConfetti(
              pieces: 34,
              onCompleted: () {
                if (mounted) setState(() => _celebrating = false);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHero() {
    final tone = switch (_mood) {
      NsMascotMood.sad => NsSpeechTone.error,
      NsMascotMood.celebrate => NsSpeechTone.success,
      NsMascotMood.curious => NsSpeechTone.info,
      _ => NsSpeechTone.neutral,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Align(
                alignment: Alignment.centerRight,
                child: NsSpeechBubble(
                  messages: [_message],
                  speaker: 'Sathi',
                  tailOnRight: true,
                  tone: tone,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          NsMascot(
            size: 82,
            mood: _mood,
            look: const Offset(0, 0.7),
            wave: _sent,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final tokens = NsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Forgot password?',
          style: TextStyle(
            fontSize: 25,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: tokens.heading,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 16),
        NsShake(
          controller: _shakeController,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NsTextField(
                    controller: _identifierController,
                    label: 'Email or phone',
                    hint: 'you@example.com or 98XXXXXXXX',
                    icon: _kind == IdentifierKind.phone
                        ? Icons.phone_iphone_rounded
                        : Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: Validators.identifier,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.username],
                    onChanged: _onChanged,
                    onFocusChange: (focused) =>
                        setState(() => _focused = focused),
                    onFieldSubmitted: (_) => _sendInstructions(),
                    labelTrailing: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: _kind == IdentifierKind.email
                          ? const NsChip(
                              key: ValueKey('email'),
                              label: 'EMAIL',
                              icon: Icons.mail_rounded,
                              compact: true,
                            )
                          : _kind == IdentifierKind.phone
                          ? const NsChip(
                              key: ValueKey('phone'),
                              label: 'PHONE',
                              icon: Icons.smartphone_rounded,
                              tone: NsChipTone.sky,
                              compact: true,
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  NsPrimaryButton(
                    label: 'Send reset link',
                    isLoading: _isLoading,
                    onPressed: _sendInstructions,
                    icon: Icons.send_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _backToSignIn,
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final tokens = NsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.mint,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.8),
          ),
          child: Icon(
            Icons.mark_email_read_rounded,
            size: 26,
            color: tokens.accentText,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Reset link sent',
          style: TextStyle(
            fontSize: 25,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: tokens.heading,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Check $_contact for the reset instructions.',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 20),
        NsPrimaryButton(
          label: 'Back to sign in',
          onPressed: _backToSignIn,
          icon: Icons.arrow_forward_rounded,
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _sent = false;
              _kind = IdentifierKind.empty;
              _identifierController.clear();
            }),
            child: const Text('Use a different email or phone'),
          ),
        ),
      ],
    );
  }
}
