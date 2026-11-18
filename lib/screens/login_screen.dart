import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_auth_heading.dart';
import '../widgets/ns_auth_scaffold.dart';
import '../widgets/ns_chip.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_google_button.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_mascot.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_staff_badge.dart';
import '../widgets/ns_text_field.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'sign_up_screen.dart';
import 'staff_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _celebrating = false;
  bool _showError = false;
  bool _googleLoading = false;
  bool _identifierFocused = false;
  bool _passwordFocused = false;
  String? _errorMessage;
  IdentifierKind _kind = IdentifierKind.empty;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  NsMascotMood get _mood {
    if (_celebrating) return NsMascotMood.celebrate;
    if (_showError) return NsMascotMood.sad;
    if (_identifierFocused || _passwordFocused) return NsMascotMood.curious;
    return NsMascotMood.happy;
  }

  Offset get _look {
    if (_passwordFocused) return const Offset(0, 0.9);
    if (_identifierFocused) return const Offset(0.1, 0.7);
    return const Offset(0.2, 0.1);
  }

  String get _message {
    if (_celebrating) return 'Welcome back! Opening your city…';
    if (_showError) {
      return _errorMessage ?? 'Hmm, check that and give it another go.';
    }
    if (_googleLoading) return 'Opening Google… pick your account.';
    if (_isLoading) return 'Checking your details…';
    if (_passwordFocused) return 'Your password stays private. Promise.';
    switch (_kind) {
      case IdentifierKind.email:
        return 'Email spotted. Looking good!';
      case IdentifierKind.phone:
        return 'Phone number it is. Nice!';
      case IdentifierKind.unknown:
        return 'Type an email or a phone number — I will sort it out.';
      case IdentifierKind.empty:
        return 'Namaste! Ready when you are.';
    }
  }

  void _onIdentifierChanged(String value) {
    final kind = Validators.identifierKind(value);
    if (kind != _kind || _showError) {
      setState(() {
        _kind = kind;
        _showError = false;
        _errorMessage = null;
      });
    }
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }

    TextInput.finishAutofillContext();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await const AuthService().signIn(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
    } on AuthFailure catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
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
      _celebrating = true;
    });
    HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading || _googleLoading) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _googleLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    final bool signedIn;
    try {
      signedIn = await const AuthService().signInWithGoogle();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _googleLoading = false;
        _showError = true;
        _errorMessage = error.message;
      });
      return;
    }

    if (!mounted) return;
    if (!signedIn) {
      setState(() => _googleLoading = false);
      return;
    }

    setState(() {
      _googleLoading = false;
      _celebrating = true;
    });
    HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _openSignUp() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SignUpScreen()));
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _openStaffSignIn() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StaffLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NsAuthScaffold(
          centerContent: true,
          topBar: _buildTopBar(),
          child: NsEntrance(child: _buildBody()),
        ),
        if (_celebrating)
          Positioned.fill(
            child: NsConfetti(
              onCompleted: () {
                if (mounted) setState(() => _celebrating = false);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const NsLogo(size: 34, depth: 2),
        const SizedBox(width: 10),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'NagarSathi',
              style: TextStyle(
                fontSize: 17,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: AppColors.forest,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        NsStaffPortalLink(onTap: _openStaffSignIn),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NsAuthHeading(
          title: 'Welcome back',
          message: _message,
          mood: _mood,
          look: _look,
          wave: _celebrating,
        ),
        const SizedBox(height: 20),
        AutofillGroup(
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
                  textInputAction: TextInputAction.next,
                  validator: Validators.identifier,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  onChanged: _onIdentifierChanged,
                  onFocusChange: (focused) {
                    setState(() => _identifierFocused = focused);
                  },
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
                const SizedBox(height: 14),
                NsTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: Validators.loginPassword,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _signIn(),
                  onChanged: (_) {
                    if (_showError) {
                      setState(() {
                        _showError = false;
                        _errorMessage = null;
                      });
                    }
                  },
                  onFocusChange: (focused) {
                    setState(() => _passwordFocused = focused);
                  },
                  labelTrailing: Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _openForgotPassword,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                NsPrimaryButton(
                  label: 'Sign in',
                  isLoading: _isLoading,
                  onPressed: _signIn,
                  icon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const NsAuthDivider(),
        const SizedBox(height: 10),
        NsGoogleButton(onPressed: _signInWithGoogle, isLoading: _googleLoading),
        const SizedBox(height: 4),
        _buildFooter(),
      ],
    );
  }

  Widget _buildFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'New to NagarSathi?',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        TextButton(
          onPressed: _openSignUp,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign up',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDeep,
            ),
          ),
        ),
      ],
    );
  }
}
