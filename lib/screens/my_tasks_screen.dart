import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/my_tasks_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_back_button.dart';
import '../widgets/member_avatar.dart';
import '../widgets/priority_tag.dart';
import 'task_detail_sheet.dart';

/// Everything assigned to the current user, across every board they're a
/// member of, grouped into Overdue / Due soon / Upcoming / No due date —
/// the same grouping the per-board due-date filters use, just spanning
/// every board at once.
class MyTasksScreen extends ConsumerWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final refs = ref.watch(myTasksProvider);

    final overdue = refs.where((r) => r.task.isOverdue).toList();
    final dueSoon = refs.where((r) => r.task.isDueSoon).toList();
    final upcoming = refs.where((r) => !r.task.isOverdue && !r.task.isDueSoon && r.task.dueDate != null).toList();
    final noDueDate = refs.where((r) => r.task.dueDate == null).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Tasks', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                      Text(
                        '${refs.length} assigned to you · across every board',
                        style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: refs.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing assigned to you right now.',
                        style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                      children: [
                        if (overdue.isNotEmpty) _Section(title: 'OVERDUE', color: AppColors.priorityHigh, refs: overdue),
                        if (dueSoon.isNotEmpty) _Section(title: 'DUE SOON', color: AppColors.priorityMedium, refs: dueSoon),
                        if (upcoming.isNotEmpty) _Section(title: 'UPCOMING', refs: upcoming),
                        if (noDueDate.isNotEmpty) _Section(title: 'NO DUE DATE', refs: noDueDate),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color? color;
  final List<BoardTaskRef> refs;
  const _Section({required this.title, this.color, required this.refs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTextStyles.meta(color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
              ),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: theme.dividerColor)),
              const SizedBox(width: 8),
              Text('${refs.length}', style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(height: 10),
          for (final ref in refs) ...[
            _TaskRow(ref: ref),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final BoardTaskRef ref;
  const _TaskRow({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TaskDetailSheet(boardId: ref.board.id, taskId: ref.task.id),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySemibold(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      PriorityTag(priority: ref.task.priority),
                      const SizedBox(width: 7),
                      Container(width: 5, height: 5, decoration: BoxDecoration(color: ref.board.color, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          ref.board.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            MemberAvatar(member: ref.task.assignee, size: 26),
          ],
        ),
      ),
    );
  }
}
