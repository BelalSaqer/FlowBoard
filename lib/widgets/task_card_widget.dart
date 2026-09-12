import 'package:flutter/material.dart';
import '../models/board_column.dart';
import '../models/task_card.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../theme/priority_colors.dart';
import 'member_avatar.dart';
import 'priority_tag.dart';

class TaskCardWidget extends StatelessWidget {
  final TaskCard task;
  final VoidCallback? onTap;

  const TaskCardWidget({super.key, required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = task.column == BoardColumnId.done;
    if (isDone) return _CompactCard(task: task, onTap: onTap);

    final rule = priorityColorsFor(task.priority, theme.brightness).accent;
    final metaBits = <String>[];
    if (task.comments.isNotEmpty) metaBits.add('${task.comments.length}');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.cardFull),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(AppRadii.cardFull),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: -13,
                top: -12,
                bottom: -11,
                child: Container(width: 2, color: rule),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySemibold(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ).copyWith(height: 1.42),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      PriorityTag(priority: task.priority),
                      if (metaBits.isNotEmpty) ...[
                        const SizedBox(width: 7),
                        Text(
                          metaBits.join(' · '),
                          style: AppTextStyles.metaSmall(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                      const Spacer(),
                      MemberAvatar(member: task.assignee, size: 22),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  final TaskCard task;
  final VoidCallback? onTap;
  const _CompactCard({required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rule = priorityColorsFor(task.priority, theme.brightness).accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Row(
            children: [
              Container(
                width: 2,
                height: 14,
                margin: const EdgeInsets.only(right: 9),
                color: rule,
              ),
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B9E77),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 9, color: Colors.white),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MemberAvatar(member: task.assignee, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
