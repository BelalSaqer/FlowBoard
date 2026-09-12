import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_column.dart';
import '../models/member.dart';
import '../models/priority.dart';
import '../providers/board_tasks_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../theme/priority_colors.dart';
import 'member_avatar.dart';

/// Bottom sheet for creating a task with full details, matching the
/// "New task" design (title, description, priority, assignee, due date).
class NewTaskSheet extends ConsumerStatefulWidget {
  final String boardId;
  final BoardColumnId initialColumn;
  final List<Member> members;
  final Member currentMember;

  const NewTaskSheet({
    super.key,
    required this.boardId,
    required this.initialColumn,
    required this.members,
    required this.currentMember,
  });

  @override
  ConsumerState<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<NewTaskSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final BoardColumnId _column = widget.initialColumn;
  Priority _priority = Priority.medium;
  late Member _assignee = widget.members.isNotEmpty ? widget.members.first : widget.currentMember;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await ref
        .read(boardTasksProvider(widget.boardId).notifier)
        .addTask(
          _column,
          _titleController.text,
          description: _descriptionController.text,
          priority: _priority,
          assignee: _assignee,
          dueDate: _dueDate,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignees = widget.members.isNotEmpty ? widget.members : [widget.currentMember];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.modalTop)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 9),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(3)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('New task', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                    ),
                    Text(_column.label, style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('TITLE'),
                      const SizedBox(height: 6),
                      _InputBox(
                        theme: theme,
                        child: TextField(
                          controller: _titleController,
                          autofocus: true,
                          style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('DESCRIPTION'),
                      const SizedBox(height: 6),
                      _InputBox(
                        theme: theme,
                        child: TextField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 4,
                          style: AppTextStyles.body(color: theme.colorScheme.onSurface),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('PRIORITY'),
                      const SizedBox(height: 8),
                      _PrioritySegments(
                        selected: _priority,
                        onChanged: (p) => setState(() => _priority = p),
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('ASSIGNEE'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final m in assignees)
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: _AssigneeOption(
                                member: m,
                                selected: m.id == _assignee.id,
                                onTap: () => setState(() => _assignee = m),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionLabel('DUE DATE'),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDueDate,
                        borderRadius: BorderRadius.circular(12),
                        child: _InputBox(
                          theme: theme,
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 17, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(
                                _formatDate(_dueDate),
                                style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).padding.bottom),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Create Task', style: AppTextStyles.bodyLarge(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
    );
  }
}

class _InputBox extends StatelessWidget {
  final ThemeData theme;
  final Widget child;
  const _InputBox({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _PrioritySegments extends StatelessWidget {
  final Priority selected;
  final void Function(Priority) onChanged;
  const _PrioritySegments({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final p in Priority.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: p == Priority.high ? 0 : 8),
              child: _PriorityPill(
                priority: p,
                active: p == selected,
                theme: theme,
                onTap: () => onChanged(p),
              ),
            ),
          ),
      ],
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final Priority priority;
  final bool active;
  final ThemeData theme;
  final VoidCallback onTap;
  const _PriorityPill({required this.priority, required this.active, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = priorityColorsFor(priority, theme.brightness);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.accent : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          priority.label,
          style: AppTextStyles.bodySmall(color: active ? Colors.white : theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AssigneeOption extends StatelessWidget {
  final Member member;
  final bool selected;
  final VoidCallback onTap;
  const _AssigneeOption({required this.member, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? member.color : Colors.transparent, width: 2),
            ),
            child: Opacity(
              opacity: selected ? 1 : 0.45,
              child: MemberAvatar(member: member, size: 44),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            member.name.split(' ').first,
            style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: selected ? 0.85 : 0.5)),
          ),
        ],
      ),
    );
  }
}
