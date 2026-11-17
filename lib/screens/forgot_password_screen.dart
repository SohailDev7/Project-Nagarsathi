import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_segmented_control.dart';
import '../widgets/ns_text_field.dart';

enum _RecoveryMode { email, phone }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  _RecoveryMode _mode = _RecoveryMode.email;
  bool _isLoading = false;
  bool _sent = false;

  String get _contact {
    return _mode == _RecoveryMode.email
        ? _emailController.text.trim()
        : _phoneController.text.trim();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendInstructions() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    TextInput.finishAutofillContext();
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NsBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: NsBackButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _sent ? _buildSuccess(context) : _buildForm(),
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

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('recovery-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Enter the email or phone linked to your account and we'll send reset instructions.",
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 28),
          NsSegmentedControl(
            segments: const ['Email', 'Phone'],
            selectedIndex: _mode.index,
            onChanged: (index) {
              FocusScope.of(context).unfocus();
              setState(() {
                _mode = _RecoveryMode.values[index];
              });
            },
          ),
          const SizedBox(height: 20),
          AutofillGroup(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _mode == _RecoveryMode.email
                  ? NsTextField(
                      key: const ValueKey('recovery-email'),
                      controller: _emailController,
                      label: 'Email address',
                      hint: 'you@example.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: Validators.email,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                    )
                  : NsTextField(
                      key: const ValueKey('recovery-phone'),
                      controller: _phoneController,
                      label: 'Phone number',
                      hint: '+977 98XXXXXXXX',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: Validators.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-\s()]'),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          NsPrimaryButton(
            label: 'Send reset link',
            isLoading: _isLoading,
            onPressed: _sendInstructions,
            icon: Icons.arrow_forward_rounded,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to sign in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      key: const ValueKey('recovery-success'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 30,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Reset link sent',
          style: TextStyle(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We sent password reset instructions to $_contact. '
          'Open them to choose a new password.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 28),
        NsPrimaryButton(
          label: 'Back to sign in',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _sent = false),
            child: const Text('Use a different email or phone'),
          ),
        ),
      ],
    );
  }
}
