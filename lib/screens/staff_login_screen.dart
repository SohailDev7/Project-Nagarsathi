import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/validators.dart';
import '../widgets/ns_auth_heading.dart';
import '../widgets/ns_auth_scaffold.dart';
import '../widgets/ns_back_button.dart';
import '../widgets/ns_bento.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_confetti.dart';
import '../widgets/ns_entrance.dart';
import '../widgets/ns_mascot.dart';
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

  NsMascotMood get _mood {
    if (_celebrating) return NsMascotMood.celebrate;
    if (_showError) return NsMascotMood.sad;
    if (_focused) return NsMascotMood.curious;
    return NsMascotMood.idle;
  }

  String get _message {
    if (_celebrating) return 'Badge verified. Opening your workspace…';
    if (_showError) return 'Check your work email and password.';
    if (_isLoading) return 'Verifying your staff access…';
    if (_focused) return 'Use the email issued by your municipality.';
    return "Staff badge ready. Let's get to work!";
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
        NsAuthHeading(
          title: 'Staff sign in',
          message: _message,
          mood: _mood,
          look: const Offset(0, 0.7),
          wave: _celebrating,
        ),
        const SizedBox(height: 18),
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
                  const SizedBox(height: 13),
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
                  const SizedBox(height: 16),
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
        const SizedBox(height: 14),
        const _StaffBento(),
        Center(
          child: TextButton(
            onPressed: _backToCitizenSignIn,
            child: const Text('Back to citizen sign in'),
          ),
        ),
      ],
    );
  }
}

class _StaffBento extends StatelessWidget {
  const _StaffBento();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: NsBentoTile(
                  icon: Icons.assignment_rounded,
                  label: 'Your queue',
                  caption: 'Citizen requests and ward updates.',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: NsBentoTile(
                  icon: Icons.verified_user_rounded,
                  label: 'Secure',
                  caption: 'Municipal-issued access.',
                  tone: NsBentoTone.sky,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: NsBentoTile(
                  icon: Icons.inbox_rounded,
                  label: 'Requests',
                  tone: NsBentoTone.sun,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: NsBentoTile(
                  icon: Icons.campaign_rounded,
                  label: 'Notices',
                  tone: NsBentoTone.sky,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: NsBentoTile(icon: Icons.map_rounded, label: 'Wards'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
