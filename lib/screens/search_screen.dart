import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import '../models/board_column.dart';
import '../models/member.dart';
import '../models/priority.dart';
import '../models/task_card.dart';
import '../providers/board_tasks_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../theme/priority_colors.dart';
import 'task_detail_sheet.dart';

/// Real (not decorative) search + filter over a board's tasks: text
/// match on title, multi-select priority and assignee filters. The
/// design prototype's "Clear" button had no handler — wiring it up here
/// since a dead button in the real app would be a bug, not a feature.
class SearchScreen extends ConsumerStatefulWidget {
  final Board board;
  const SearchScreen({super.key, required this.board});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  bool _filterOpen = false;
  final Set<Priority> _fPriority = {};
  final Set<String> _fAssigneeIds = {};

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  int get _filterCount => _fPriority.length + _fAssigneeIds.length;

  List<TaskCard> _filter(Map<BoardColumnId, List<TaskCard>> tasksByColumn) {
    final query = _queryController.text.trim().toLowerCase();
    final all = tasksByColumn.values.expand((l) => l).toList();
    return all.where((t) {
      if (query.isNotEmpty &&
          !t.title.toLowerCase().contains(query) &&
          !t.description.toLowerCase().contains(query)) {
        return false;
      }
      if (_fPriority.isNotEmpty && !_fPriority.contains(t.priority)) return false;
      if (_fAssigneeIds.isNotEmpty && !_fAssigneeIds.contains(t.assignee.id)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksByColumn = ref.watch(boardTasksProvider(widget.board.id));
    final hits = _filter(tasksByColumn);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.board.name, style: AppTextStyles.h3(color: theme.colorScheme.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                          '${hits.length} matches',
                          style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              onChanged: (_) => setState(() {}),
                              style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Search tasks'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  InkWell(
                    onTap: () => setState(() => _filterOpen = !_filterOpen),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _filterOpen ? AppColors.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Icon(Icons.tune, size: 18, color: _filterOpen ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          if (_filterCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                                decoration: BoxDecoration(
                                  color: AppColors.priorityHigh,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                                ),
                                child: Text(
                                  '$_filterCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_filterOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: _FilterPanel(
                  board: widget.board,
                  selectedPriorities: _fPriority,
                  selectedAssigneeIds: _fAssigneeIds,
                  onTogglePriority: (p) => setState(() => _fPriority.contains(p) ? _fPriority.remove(p) : _fPriority.add(p)),
                  onToggleAssignee: (id) => setState(() => _fAssigneeIds.contains(id) ? _fAssigneeIds.remove(id) : _fAssigneeIds.add(id)),
                  onClear: () => setState(() {
                    _fPriority.clear();
                    _fAssigneeIds.clear();
                  }),
                  onApply: () => setState(() => _filterOpen = false),
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: hits.isEmpty
                  ? Center(
                      child: Text('No matching tasks', style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                      itemCount: hits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, i) => _HitCard(
                        task: hits[i],
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => TaskDetailSheet(boardId: widget.board.id, taskId: hits[i].id),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final Board board;
  final Set<Priority> selectedPriorities;
  final Set<String> selectedAssigneeIds;
  final void Function(Priority) onTogglePriority;
  final void Function(String) onToggleAssignee;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const _FilterPanel({
    required this.board,
    required this.selectedPriorities,
    required this.selectedAssigneeIds,
    required this.onTogglePriority,
    required this.onToggleAssignee,
    required this.onClear,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionDivider(label: 'Priority', theme: theme),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in Priority.values) ...[
                _PriorityChip(priority: p, selected: selectedPriorities.contains(p), onTap: () => onTogglePriority(p)),
                if (p != Priority.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionDivider(label: 'Assignee', theme: theme),
          const SizedBox(height: 11),
          Row(
            children: [
              for (final m in board.members) ...[
                _AssigneeChip(member: m, selected: selectedAssigneeIds.contains(m.id), onTap: () => onToggleAssignee(m.id)),
                if (m != board.members.last) const SizedBox(width: 11),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text('Clear', style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)).copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onApply,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('Apply', style: AppTextStyles.bodySmall(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _SectionDivider({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        const SizedBox(width: 9),
        Expanded(child: Container(height: 1, color: theme.dividerColor)),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final Priority priority;
  final bool selected;
  final VoidCallback onTap;
  const _PriorityChip({required this.priority, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = priorityColorsFor(priority, theme.brightness);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accent : Colors.transparent,
          border: Border.all(color: selected ? colors.accent : theme.dividerColor),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          priority.label,
          style: AppTextStyles.bodySmall(color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.6)).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AssigneeChip extends StatelessWidget {
  final Member member;
  final bool selected;
  final VoidCallback onTap;
  const _AssigneeChip({required this.member, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: selected ? 1 : 0.45,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: member.color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(
            member.initials,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  final TaskCard task;
  final VoidCallback onTap;
  const _HitCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = priorityColorsFor(task.priority, theme.brightness);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.cardFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppRadii.cardFull),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Stack(
          children: [
            Positioned(left: -13, top: -12, bottom: -12, child: Container(width: 2, color: colors.accent)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySemibold(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(6)),
                      child: Text(task.priority.label.toUpperCase(), style: AppTextStyles.badge(color: colors.text).copyWith(fontSize: 10)),
                    ),
                    const SizedBox(width: 7),
                    Text(task.column.label, style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                    const Spacer(),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: task.assignee.color, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(task.assignee.initials, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
