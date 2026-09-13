import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_entry.dart';
import '../models/board.dart';
import '../providers/board_tasks_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_back_button.dart';

class _ActivityRow {
  final ActivityEntry entry;
  final String taskTitle;
  const _ActivityRow(this.entry, this.taskTitle);
}

class ActivityScreen extends ConsumerWidget {
  final Board board;
  const ActivityScreen({super.key, required this.board});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasksByColumn = ref.watch(boardTasksProvider(board.id));

    final rows = <_ActivityRow>[];
    for (final tasks in tasksByColumn.values) {
      for (final task in tasks) {
        for (final entry in task.activity) {
          rows.add(_ActivityRow(entry, task.title));
        }
      }
    }
    rows.sort((a, b) => b.entry.time.compareTo(a.entry.time));

    final groups = <String, List<_ActivityRow>>{};
    for (final row in rows) {
      final key = _dayLabel(row.entry.time);
      groups.putIfAbsent(key, () => []).add(row);
    }

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
                      Text('Activity', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                      Text(
                        '${board.name} · all members',
                        style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: _VelocityChart(rows: rows),
              ),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'No activity yet',
                        style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                      children: [
                        for (final key in groups.keys) ...[
                          Row(
                            children: [
                              Text(
                                key.toUpperCase(),
                                style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Container(height: 1, color: theme.dividerColor)),
                              const SizedBox(width: 8),
                              Text(
                                '${groups[key]!.length} events',
                                style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final row in groups[key]!) ...[
                            _ActivityTile(row: row),
                            const SizedBox(height: 14),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(time.year, time.month, time.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[time.month - 1]} ${time.day}';
  }
}

/// A 7-day "cards completed per day" bar chart, derived entirely from
/// existing activity-log text — no separate history table needed, since
/// every move-to-Done already leaves a timestamped entry behind. Hand-
/// rolled from plain Containers (no charting package) to match the
/// vector-only, no-image-assets style used elsewhere (see
/// _BoardStackIllustration in empty_states.dart).
class _VelocityChart extends StatelessWidget {
  final List<_ActivityRow> rows;
  const _VelocityChart({required this.rows});

  static const _barHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];

    final counts = {for (final d in days) d: 0};
    for (final row in rows) {
      if (!row.entry.text.endsWith('to Done')) continue;
      final d = DateTime(row.entry.time.year, row.entry.time.month, row.entry.time.day);
      if (counts.containsKey(d)) counts[d] = counts[d]! + 1;
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);

    const weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'VELOCITY',
                style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
              const Spacer(),
              Text(
                '$total completed this week',
                style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _barHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Tooltip(
                        message: '${counts[d]} completed on ${d.month}/${d.day}',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: maxCount == 0 ? 4 : 4 + (_barHeight - 4) * (counts[d]! / maxCount),
                          decoration: BoxDecoration(
                            color: d == today ? AppColors.primary : AppColors.primary.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Text(
                    weekdayInitials[days[i].weekday - 1],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.metaTiny(color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityRow row;
  const _ActivityTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Every activity string is written with the placeholder "this card";
    // substitute the real title here so the sentence reads correctly in
    // this cross-task aggregate view without rewriting stored text.
    final text = row.entry.text.replaceFirst('this card', "'${row.taskTitle}'");
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: row.entry.dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RichActivityText(text: text, theme: theme),
              const SizedBox(height: 2),
              Text(_formatTime(row.entry.time), style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _RichActivityText extends StatelessWidget {
  final String text;
  final ThemeData theme;
  const _RichActivityText({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    // Bold whatever's inside single quotes (the task title) for scannability.
    final match = RegExp(r"^(.*?)'(.*)'(.*)$").firstMatch(text);
    if (match == null) {
      return Text(text, style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(height: 1.4));
    }
    return RichText(
      text: TextSpan(
        style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(height: 1.4),
        children: [
          TextSpan(text: match.group(1)),
          TextSpan(text: "'${match.group(2)}'", style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: match.group(3)),
        ],
      ),
    );
  }
}
