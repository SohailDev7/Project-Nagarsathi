import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ns_auth_scaffold.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
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
  bool _celebrating = false;
  bool _showError = false;
  bool _focused = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _message {
    if (_celebrating) return 'Badge verified. Opening your workspace…';
    if (_showError) return 'Check your work email and password.';
    if (_isLoading) return 'Verifying your staff access…';
    if (_focused) return 'Use the email issued by your municipality.';
    return 'Municipal-issued accounts only.';
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }

    final staffEmail = _emailController.text.trim();
    TextInput.finishAutofillContext();
    setState(() => _isLoading = true);

    // UI-only, matching citizen sign-in. A future authentication service must
    // verify credentials and a server-issued staff role before opening this page.
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    // A back navigation can start before this state is disposed. Ignore the
    // completed attempt if the user has already left the staff sign-in route.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = false;
      _celebrating = true;
    });
    HapticFeedback.mediumImpact();

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;

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
    return Stack(
      children: [
        NsAuthScaffold(
          staff: true,
          topBar: Row(
            children: [
              NsBackButton(onPressed: _backToCitizenSignIn),
              const Spacer(),
              const NsStaffBadge(compact: true),
            ],
          ),
          bottom: TextButton(
            onPressed: _backToCitizenSignIn,
            child: const Text('Back to citizen sign in'),
          ),
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

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        NsCard(
          padding: const EdgeInsets.all(16),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NsTextField(
                    controller: _emailController,
                    label: 'Work email address',
                    hint: 'you@municipality.gov.np',
                    icon: Icons.mail_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.username],
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    onChanged: (_) {
                      if (_showError) setState(() => _showError = false);
                    },
                    onFocusChange: (focused) =>
                        setState(() => _focused = focused),
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
                      if (_showError) setState(() => _showError = false);
                    },
                    onFocusChange: (focused) =>
                        setState(() => _focused = focused),
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
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1.5),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: AppColors.muted,
              ),
            ),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                'Access is issued by your municipality.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.28),
            offset: const Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(
              Icons.badge_rounded,
              size: 24,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STAFF PORTAL',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryLight,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Staff sign in',
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _message,
                    key: ValueKey(_message),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: _showError
                          ? const Color(0xFFFFC4BD)
                          : Colors.white.withValues(alpha: 0.74),
                    ),
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
