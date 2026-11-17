import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_city_art.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_text_field.dart';
import 'home_screen.dart';

/// Multi-step sign-up: name → email → phone → password.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const _totalSteps = 4;
  static const _phoneStep = 2;
  static const _lastStep = 3;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _formKeys = List<GlobalKey<FormState>>.generate(
    _totalSteps,
    (_) => GlobalKey<FormState>(),
  );

  int _step = 0;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return;

    if (_step == _lastStep) {
      _createAccount();
      return;
    }
    setState(() => _step += 1);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
  }

  void _skipPhone() {
    FocusScope.of(context).unfocus();
    setState(() => _step = _lastStep);
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    if (!(_formKeys[_lastStep].currentState?.validate() ?? false)) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the terms to continue.'),
        ),
      );
      return;
    }

    TextInput.finishAutofillContext();
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() => _isLoading = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        body: NsBackground(
          child: SafeArea(
            child: AutofillGroup(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                    child: Row(
                      children: [
                        NsBackButton(onPressed: _back),
                        const Spacer(),
                        Text(
                          '${_step + 1} of $_totalSteps',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _totalSteps,
                        minHeight: 2.5,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 34, 24, 12),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 400),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOut,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.03),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildStep(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Decorative skyline pinned above the primary action so
                        // the spare room under the fields reads as intentional.
                        if (_step != _lastStep) const _WizardArt(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NsTextField(
                              controller: _nameController,
                              label: 'Full name',
                              hint: 'Your full name',
                              icon: Icons.person_outline_rounded,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: Validators.name,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 16),
                            NsTextField(
                              controller: _emailController,
                              label: 'Email address',
                              hint: 'you@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: Validators.email,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            NsTextField(
                              controller: _phoneController,
                              label: 'Phone number (optional)',
                              hint: '+977 98XXXXXXXX',
                              icon: Icons.phone_iphone_rounded,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              validator: Validators.optionalPhone,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-\s()]'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            NsTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Create a password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              validator: Validators.password,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 16),
                            NsTextField(
                              controller: _confirmController,
                              label: 'Confirm password',
                              hint: 'Re-enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: Validators.confirmPassword(
                                _passwordController,
                              ),
                              onFieldSubmitted: (_) => _createAccount(),
                            ),
                            const SizedBox(height: 20),
                            _TermsRow(
                              accepted: _acceptedTerms,
                              onToggle: () {
                                setState(() {
                                  _acceptedTerms = !_acceptedTerms;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            NsPrimaryButton(
                              label: 'Create account',
                              isLoading: _isLoading,
                              onPressed: _createAccount,
                              icon: Icons.arrow_forward_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Already have an account?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.muted,
                          ),
                        ),
                        TextButton(
                          onPressed: _goToLogin,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Checkbox(
            value: accepted,
            onChanged: (value) => onChanged(value ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!accepted),
            child: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.muted,
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Sign in',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
