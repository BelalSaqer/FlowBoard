import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/flowboard_logo.dart';

/// Branded loading state shown while the app resolves what to show next
/// (onboarding decision, then Firebase Auth state, then profile
/// resolution) — picks up visually where the pre-Flutter HTML splash in
/// web/index.html leaves off, so there's no jarring bare-spinner gap
/// between page load and the sign-in screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlowBoardLogo(size: 72),
            const SizedBox(height: 18),
            Text(
              'FlowBoard',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
