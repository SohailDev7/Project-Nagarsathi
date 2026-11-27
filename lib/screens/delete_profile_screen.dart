import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ns_background.dart';
import '../widgets/ns_card.dart';
import '../widgets/ns_outline_button.dart';
import '../widgets/ns_primary_button.dart';
import '../widgets/ns_text_field.dart';
import 'login_screen.dart';

class DeleteProfileScreen extends StatefulWidget {
  const DeleteProfileScreen({
    super.key,
    this.authService = const AuthService(),
  });

  final AuthService authService;

  @override
  State<DeleteProfileScreen> createState() => _DeleteProfileScreenState();
}

class _DeleteProfileScreenState extends State<DeleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  CitizenDeletionMethod? _method;
  CitizenDeletionSmsChallenge? _smsChallenge;
  CitizenDeletionResult? _result;
  String? _phone;
  String? _error;
  bool _confirmed = false;
  bool _isLoading = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    try {
      _method = widget.authService.deletionMethod;
      if (_method == CitizenDeletionMethod.sms) {
        _phone = widget.authService.deletionPhoneNumber;
      }
    } on AuthFailure catch (error) {
      _error = error.message;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendSms() async {
    if (_isLoading || _resendSeconds > 0) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final challenge = await widget.authService.requestDeletionSmsCode(
        previous: _smsChallenge,
      );
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _smsChallenge = challenge;
        _resendSeconds = 60;
      });
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _resendSeconds--);
        if (_resendSeconds == 0) timer.cancel();
      });
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not send the code. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProfile() async {
    if (_isLoading || _method == null) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_confirmed) {
      setState(
        () => _error = 'Confirm that you understand deletion is permanent.',
      );
      return;
    }
    if (_method == CitizenDeletionMethod.sms && _smsChallenge == null) {
      setState(() => _error = 'Request an SMS verification code first.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.authService.deleteCitizenProfile(
        password: _passwordController.text,
        smsChallenge: _smsChallenge,
        smsCode: _codeController.text,
      );
      if (!mounted) return;
      _passwordController.clear();
      _codeController.clear();
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) setState(() => _result = result);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not confirm deletion. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  void _backToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final canLeave = !_isLoading && _result == null;
    return PopScope(
      canPop: canLeave,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delete my profile'),
          backgroundColor: tokens.background,
          automaticallyImplyLeading: false,
          leading: canLeave
              ? IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
        body: NsBackground(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
              child: _result == null ? _buildForm() : _buildResult(_result!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final tokens = NsColors.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Delete your profile?',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
            ),
          ),
          const SizedBox(height: 12),
          NsCard(
            borderColor: tokens.errorBorder,
            child: Text(
              'Your account is deactivated now and permanently deleted after '
              '30 days. Sign in within that time to keep it.\n\n'
              'After deletion your profile, phone number, email and sign-in '
              'credentials are removed, and your public reports and comments '
              'remain without your identity. Deletion cannot be undone.',
              style: TextStyle(color: tokens.ink, height: 1.5),
            ),
          ),
          const SizedBox(height: 22),
          if (_method == CitizenDeletionMethod.password)
            NsTextField(
              key: const Key('deletion-password'),
              controller: _passwordController,
              label: 'Confirm your password',
              hint: 'Enter your current password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              enabled: !_isLoading,
              autofillHints: const [AutofillHints.password],
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Enter your password to confirm deletion.'
                  : null,
            ),
          if (_method == CitizenDeletionMethod.sms) ...[
            Text(
              'Verify with an SMS code sent to your registered phone: $_phone',
              style: TextStyle(color: tokens.ink, height: 1.5),
            ),
            const SizedBox(height: 12),
            NsOutlineButton(
              key: const Key('send-deletion-sms'),
              label: _resendSeconds > 0
                  ? 'Resend in $_resendSeconds s'
                  : (_smsChallenge == null
                        ? 'Send verification code'
                        : 'Resend code'),
              onPressed: _isLoading || _resendSeconds > 0 ? null : _sendSms,
            ),
            if (_smsChallenge != null) ...[
              const SizedBox(height: 16),
              if (_smsChallenge!.autoCredential != null)
                const Text('Your phone was verified. You can confirm deletion.')
              else
                NsTextField(
                  key: const Key('deletion-sms-code'),
                  controller: _codeController,
                  label: 'SMS verification code',
                  hint: '6-digit code',
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                      ? null
                      : 'Enter the 6-digit SMS verification code.',
                ),
            ],
          ],
          if (_method == CitizenDeletionMethod.google ||
              _method == CitizenDeletionMethod.facebook)
            Text(
              _method == CitizenDeletionMethod.google
                  ? 'You will verify with the same Google account you used to sign in.'
                  : 'You will verify with the same Facebook account you used to sign in.',
              style: TextStyle(color: tokens.ink, height: 1.5),
            ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              key: const Key('confirm-profile-deletion'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I understand this is permanent.'),
              value: _confirmed,
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const Key('profile-deletion-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 22),
          NsPrimaryButton(
            key: const Key('confirm-delete-profile'),
            label: 'Delete my profile',
            icon: Icons.person_remove_outlined,
            color: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            borderColor: tokens.errorBorder,
            shadowColor: tokens.errorBorder,
            isLoading: _isLoading,
            onPressed: _method == null ? null : _deleteProfile,
          ),
          const SizedBox(height: 14),
          NsOutlineButton(
            label: 'Keep my profile',
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(CitizenDeletionResult result) {
    final tokens = NsColors.of(context);
    final deleteAt = result.deleteAt;
    final title = result.completed
        ? 'Profile deleted'
        : (result.scheduled ? 'Account deactivated' : 'Deletion requested');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          result.completed
              ? Icons.check_circle_outline_rounded
              : Icons.hourglass_bottom_rounded,
          size: 58,
          color: result.completed ? tokens.accentText : tokens.errorBorder,
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: tokens.heading,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          result.completed
              ? 'Your profile and personal data have been removed. '
                    'Your public contributions no longer identify you. '
                    'You have been signed out.'
              : result.scheduled
              ? 'Your account is deactivated and you have been signed out. '
                    '${deleteAt == null ? 'It will be permanently deleted when the 30-day window ends.' : 'It will be permanently deleted on ${_formatDate(deleteAt)} unless you sign in before then and choose "Keep my account".'}' 
              : 'Your request is saved and you have been signed out. '
                    'We will finish removing your personal data within 30 days '
                    'and remove your identity from public contributions.',
          textAlign: TextAlign.center,
          style: TextStyle(color: tokens.ink, height: 1.5),
        ),
        if (result.emailStatus != DeletionEmailStatus.unavailable) ...[
          const SizedBox(height: 16),
          Text(
            result.emailStatus == DeletionEmailStatus.sent
                ? 'A confirmation has been sent to your email.'
                : 'Your confirmation email will be sent when cleanup finishes. '
                      'If delivery is interrupted, we will retry it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.muted, height: 1.5),
          ),
        ],
        const SizedBox(height: 28),
        NsPrimaryButton(
          key: const Key('deletion-back-to-sign-in'),
          label: 'Back to sign in',
          onPressed: _backToSignIn,
        ),
      ],
    );
  }
}
