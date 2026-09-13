import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../providers/auth_provider.dart';
import '../providers/boards_provider.dart';
import '../providers/profile_provider.dart';
import '../services/deep_link.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'board_detail_screen.dart';
import 'boards_list_screen.dart';
import 'sign_in_screen.dart';
import 'splash_screen.dart';

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
      loading: () => const SplashScreen(),
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
        final joinBoardId = takeInitialJoinBoardId();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (ref.read(currentMemberStateProvider) != m) {
            ref.read(currentMemberStateProvider.notifier).state = m;
          }
          if (joinBoardId != null) {
            await _handleJoinLink(ref, joinBoardId, m);
          }
        });
        return const BoardsListScreen();
      },
      loading: () => const SplashScreen(),
      error: (err, _) => _ErrorScreen(error: err, onRetry: () => ref.invalidate(currentMemberProvider)),
    );
  }

  // Uses the app-level navigatorKey/scaffoldMessengerKey rather than a
  // widget's BuildContext: this fires from a provider callback that can
  // outlive whichever specific Element happened to be build()ing when it
  // was scheduled, so there's no single BuildContext guaranteed to still
  // be mounted after the network round-trip to Firestore.
  Future<void> _handleJoinLink(WidgetRef ref, String boardId, Member me) async {
    try {
      final board = await ref.read(boardsProvider.notifier).joinBoardByLink(boardId, me);
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => BoardDetailScreen(board: board)));
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(e is StateError ? e.message : 'Couldn\'t open that invite link.')),
      );
    }
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
