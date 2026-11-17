import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_logo.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_staff_badge.dart';
import '../widgets/ns_text_field.dart';
import 'login_screen.dart';
import 'staff_home_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final staffEmail = _emailController.text.trim();
    TextInput.finishAutofillContext();
    setState(() => _isLoading = true);

    // UI-only, matching citizen sign-in. A future authentication service must
    // verify credentials and a server-issued staff role before opening this page.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // A back navigation can start before this state is disposed. Ignore the
    // completed attempt if the user has already left the staff sign-in route.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      setState(() => _isLoading = false);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => StaffHomeScreen(staffEmail: staffEmail),
      ),
      (route) => false,
    );
  }

  void _backToCitizenSignIn() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    // After staff sign-out this screen is the root route, so replace it rather
    // than leaving a back button that cannot return to citizen sign-in.
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
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
                      child: NsBackButton(onPressed: _backToCitizenSignIn),
                    ),
                    const SizedBox(height: 28),
                    NsEntrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [NsLogo(), NsStaffBadge()],
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Staff sign in',
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.08,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Use your work email to access your staff workspace.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NsTextField(
                              controller: _emailController,
                              label: 'Work email address',
                              hint: 'you@municipality.gov.np',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: Validators.email,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.username],
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            NsTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: Validators.loginPassword,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _signIn(),
                            ),
                            const SizedBox(height: 24),
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
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: _backToCitizenSignIn,
                        child: const Text('Back to citizen sign in'),
                      ),
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
