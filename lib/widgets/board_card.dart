import 'package:flutter/material.dart';
import '../models/board.dart';
import '../providers/board_tasks_provider.dart';
import '../models/board_column.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'member_avatar.dart';

class BoardCard extends StatelessWidget {
  final Board board;
  final BoardTasksState tasksByColumn;
  final int liveCount;
  final VoidCallback onTap;

  const BoardCard({
    super.key,
    required this.board,
    required this.tasksByColumn,
    required this.liveCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = tasksByColumn.values.fold<int>(0, (a, l) => a + l.length);
    final done = tasksByColumn[BoardColumnId.done]?.length ?? 0;
    final pct = total == 0 ? 0.0 : done / total;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: board.color, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      board.name,
                      style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  if (liveCount > 0)
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('$liveCount', style: AppTextStyles.metaSmall(color: AppColors.success).copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(board.color),
                  ),
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: (board.members.length - 1) * 17.0 + 24,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < board.members.length; i++)
                          Positioned(
                            left: i * 17.0,
                            child: MemberAvatar(member: board.members[i], size: 24, ringColor: theme.colorScheme.surface),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: board.members.length * 17.0 + 12),
                  Expanded(
                    child: Text(
                      'updated ${_relativeTime(board.updatedAt)}',
                      style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                  ),
                  Text('$done / $total', style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)).copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d ago';
}
