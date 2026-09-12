import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';

/// A small decorative "stack of board cards" illustration, built from
/// plain containers to match the app's vector-only visual style (no
/// image assets used elsewhere).
class _BoardStackIllustration extends StatelessWidget {
  const _BoardStackIllustration();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            top: 20,
            child: Container(
              width: 170,
              height: 110,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 4,
            child: Container(
              width: 178,
              height: 118,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 46, height: 8, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 10),
                      Container(width: 30, height: 8, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(left: BorderSide(color: AppColors.priorityLow, width: 3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 26,
                    width: 92,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(left: BorderSide(color: AppColors.priorityMedium, width: 3)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on the boards list when the user has no boards at all.
class BoardsEmptyState extends StatelessWidget {
  final VoidCallback onCreateBoard;
  final VoidCallback onJoinWithLink;

  const BoardsEmptyState({super.key, required this.onCreateBoard, required this.onJoinWithLink});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const _BoardStackIllustration(),
          const SizedBox(height: 28),
          Text('Create your first board', style: AppTextStyles.h3(color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            'Boards hold your columns and cards.\nInvite the team once it is set up.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)).copyWith(height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCreateBoard,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
              ),
              child: Text('+ New board', style: AppTextStyles.bodyLarge(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onJoinWithLink,
            child: Text(
              'Join with an invite link',
              style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown inside a board when it has zero tasks in any column.
class BoardTasksEmptyState extends StatelessWidget {
  final VoidCallback? onAddFirstTask;

  const BoardTasksEmptyState({super.key, required this.onAddFirstTask});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 260,
              height: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ColumnGhost(theme: theme, label: 'TO DO', rows: 2),
                  _ColumnGhost(theme: theme, label: 'DOING', rows: 1),
                  _ColumnGhost(theme: theme, label: 'DONE', rows: 2),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('No tasks yet', style: AppTextStyles.h3(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Add the first card and drag it across the columns as the work moves.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)).copyWith(height: 1.5),
            ),
            if (onAddFirstTask != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAddFirstTask,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                ),
                child: Text('+ Add your first task', style: AppTextStyles.bodyLarge(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnGhost extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final int rows;
  const _ColumnGhost({required this.theme, required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.metaTiny(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (var i = 0; i < rows; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
