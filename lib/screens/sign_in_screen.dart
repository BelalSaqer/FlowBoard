import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../widgets/flowboard_logo.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;
  bool _emailExpanded = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithEmail(FirebaseAuth auth) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await signInWithEmail(auth, email, password);
    } on FirebaseAuthException catch (e) {
      // Firebase now returns the same ambiguous code (invalid-credential,
      // sometimes still wrong-password/user-not-found on older configs) for
      // both "no such account" and "wrong password", as an email-enumeration
      // protection. We can't tell them apart, so offer account creation for
      // either case rather than claiming to know which one it is.
      const ambiguousCodes = {'invalid-credential', 'user-not-found', 'wrong-password'};
      if (ambiguousCodes.contains(e.code)) {
        if (mounted) setState(() => _busy = false);
        final createAccount = await _confirmCreateAccount(email);
        if (createAccount != true) return;
        await _run(() => createAccountWithEmail(auth, email, password));
        return;
      }
      if (mounted) setState(() => _error = friendlyAuthErrorMessage(e));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmCreateAccount(String email) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Couldn\'t sign in'),
        content: Text(
          'Either the password is wrong, or there\'s no account yet for $email. Create a new account with this email and password?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create account', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _forgotPassword(FirebaseAuth auth) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first, then tap "Forgot password?".');
      return;
    }
    try {
      await sendPasswordReset(auth, email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.read(firebaseAuthProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const FlowBoardLogo(size: 64),
              const SizedBox(height: 20),
              Text('FlowBoard', style: AppTextStyles.h1(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 6),
              Text(
                'Real-time boards your team can edit together.',
                style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 36),
              if (_error != null) ...[
                Text(_error!, style: AppTextStyles.bodySmall(color: AppColors.priorityHigh)),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _busy ? null : () => _run(() => signInWithGoogle(auth)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Continue with Google', style: AppTextStyles.bodyLarge(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              _EmailSection(
                expanded: _emailExpanded,
                busy: _busy,
                emailController: _emailController,
                passwordController: _passwordController,
                onToggle: () => setState(() => _emailExpanded = !_emailExpanded),
                onSignIn: () => _signInWithEmail(auth),
                onForgotPassword: () => _forgotPassword(auth),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : () => _run(() => signInAsGuest(auth)),
                child: Text(
                  'Continue as Guest',
                  style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'By continuing you agree to the Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailSection extends StatelessWidget {
  final bool expanded;
  final bool busy;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onToggle;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;

  const _EmailSection({
    required this.expanded,
    required this.busy,
    required this.emailController,
    required this.passwordController,
    required this.onToggle,
    required this.onSignIn,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Continue with Email',
                      style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _boxedField(theme, emailController, 'you@company.com', obscure: false),
                  const SizedBox(height: 10),
                  _boxedField(theme, passwordController, 'Password', obscure: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: busy ? null : onForgotPassword,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text('Forgot password?', style: AppTextStyles.bodySmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: busy ? null : onSignIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                        child: busy
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Sign in', style: AppTextStyles.bodySmall(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _boxedField(ThemeData theme, TextEditingController controller, String hint, {required bool obscure}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppTextStyles.body(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
        ),
      ),
    );
  }
}
