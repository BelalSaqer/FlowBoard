import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'boards_list_screen.dart';
import 'sign_in_screen.dart';

/// Holds the resolved current-user [Member] once sign-in + profile
/// resolution complete, so the rest of the app can read it synchronously
/// instead of threading async state through every provider.
final currentMemberStateProvider = StateProvider<Member?>((ref) => null);

/// Routes between the sign-in screen and the app based on real Firebase
/// Auth state, then resolves the signed-in user's profile before
/// entering the boards list.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) => user == null ? const SignInScreen() : const _ProfileGate(),
      loading: () => const _Loading(),
      error: (err, _) => _ErrorScreen(error: err, onRetry: () => ref.invalidate(authStateProvider)),
    );
  }
}

class _ProfileGate extends ConsumerWidget {
  const _ProfileGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(currentMemberProvider);

    return member.when(
      data: (m) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ref.read(currentMemberStateProvider) != m) {
            ref.read(currentMemberStateProvider.notifier).state = m;
          }
        });
        return const BoardsListScreen();
      },
      loading: () => const _Loading(),
      error: (err, _) => _ErrorScreen(error: err, onRetry: () => ref.invalidate(currentMemberProvider)),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not connect to Firebase', style: AppTextStyles.h3(color: AppColors.textPrimaryLight)),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(color: AppColors.textMutedLight),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
