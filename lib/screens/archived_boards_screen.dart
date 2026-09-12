import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import '../providers/boards_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'auth_gate.dart';

/// Lists boards the current user belongs to that have been archived, with
/// a one-tap restore. Archiving hides a board from the main list rather
/// than deleting it, so this is the recovery path back.
class ArchivedBoardsScreen extends ConsumerStatefulWidget {
  const ArchivedBoardsScreen({super.key});

  @override
  ConsumerState<ArchivedBoardsScreen> createState() => _ArchivedBoardsScreenState();
}

class _ArchivedBoardsScreenState extends ConsumerState<ArchivedBoardsScreen> {
  late Future<List<Board>> _future = _load();

  Future<List<Board>> _load() {
    final uid = ref.read(currentMemberStateProvider)?.id;
    if (uid == null) return Future.value(const []);
    return ref.read(boardsProvider.notifier).fetchArchivedBoards(uid);
  }

  Future<void> _restore(Board board) async {
    await ref.read(boardsProvider.notifier).unarchiveBoard(board.id);
    setState(() => _future = _load());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored "${board.name}"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BackButton(onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Text('Archived boards', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: FutureBuilder<List<Board>>(
                  future: _future,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    final boards = snap.data!;
                    if (boards.isEmpty) {
                      return Center(
                        child: Text(
                          'No archived boards.',
                          style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: boards.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final board = boards[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: board.color, shape: BoxShape.circle)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(board.name, style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w600)),
                              ),
                              TextButton(
                                onPressed: () => _restore(board),
                                child: const Text('Restore', style: TextStyle(color: AppColors.primary)),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(Icons.arrow_back_ios_new, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}
