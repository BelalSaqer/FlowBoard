import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../models/conflict_info.dart';
import '../models/task_card.dart';
import '../providers/board_tasks_provider.dart';
import '../providers/boards_provider.dart';
import '../services/deep_link.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../theme/label_colors.dart';
import '../widgets/member_avatar.dart';
import '../widgets/priority_tag.dart';
import '../widgets/rich_text_content.dart';
import 'auth_gate.dart';

const _maxAttachmentBytes = 120 * 1024;

class TaskDetailSheet extends ConsumerStatefulWidget {
  final String boardId;
  final String taskId;
  const TaskDetailSheet({super.key, required this.boardId, required this.taskId});

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  final _commentController = TextEditingController();
  bool _aiLoading = false;

  // Snapshot of `updatedAt` as of opening this sheet. A later `updatedAt`
  // from someone other than the current user is a real concurrent edit,
  // detected off the live Firestore listener rather than simulated.
  DateTime? _baselineUpdatedAt;
  bool _baselineCaptured = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Direct-tap, no intermediate dialog — same browser-gesture requirement
  // as the profile photo picker: `pickImage()` has to fire with no
  // `await` gap from the tap or the native file dialog silently no-ops.
  Future<void> _addAttachment(TaskCard task) async {
    if (task.attachments.length >= BoardTasksNotifier.maxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Up to ${BoardTasksNotifier.maxAttachments} attachments per task.')),
      );
      return;
    }
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open the photo picker: $e')));
      }
      return;
    }
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file could not be read as an image.')),
        );
      }
      return;
    }

    final longestSide = decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longestSide > 256
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 256 : null,
            height: decoded.height > decoded.width ? 256 : null,
          )
        : decoded;

    var quality = 80;
    var jpg = img.encodeJpg(resized, quality: quality);
    while (jpg.length > _maxAttachmentBytes && quality > 20) {
      quality -= 15;
      jpg = img.encodeJpg(resized, quality: quality);
    }
    if (jpg.length > _maxAttachmentBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That image is too large even after compression — try a different one.')),
        );
      }
      return;
    }

    await ref.read(boardTasksProvider(widget.boardId).notifier).addAttachment(task.id, base64Encode(jpg));
  }

  void _viewAttachment(String base64Image, bool canEdit, TaskCard task) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(base64Decode(base64Image), fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  if (canEdit)
                    IconButton(
                      tooltip: 'Remove attachment',
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                      onPressed: () {
                        ref.read(boardTasksProvider(widget.boardId).notifier).removeAttachment(task.id, base64Image);
                        Navigator.of(context).pop();
                      },
                    ),
                  IconButton(
                    tooltip: 'Close',
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAi() async {
    setState(() => _aiLoading = true);
    await ref
        .read(boardTasksProvider(widget.boardId).notifier)
        .generateAiSubtasks(widget.taskId);
    if (mounted) setState(() => _aiLoading = false);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.priorityHigh)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(boardTasksProvider(widget.boardId).notifier);
    final title = notifier.taskById(widget.taskId)?.title ?? 'Task';
    Navigator.of(context).maybePop();

    // The delete is deferred until the snackbar closes without the user
    // tapping Undo — shown on the app-level ScaffoldMessenger (not this
    // sheet's own context, which is gone the instant it pops) so the
    // undo window survives navigating away from the task.
    final controller = scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('"$title" deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        duration: const Duration(seconds: 5),
      ),
    );
    final reason = await controller?.closed;
    if (reason != SnackBarClosedReason.action) {
      await notifier.deleteTask(widget.taskId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(boardTasksProvider(widget.boardId).notifier);
    ref.watch(boardTasksProvider(widget.boardId));
    final task = notifier.taskById(widget.taskId);
    final taskDoc = notifier.taskDocById(widget.taskId);

    if (task == null) return const SizedBox.shrink();

    final boardMatches = ref.watch(boardsProvider).where((b) => b.id == widget.boardId);
    final board = boardMatches.isEmpty ? null : boardMatches.first;
    final myId = ref.watch(currentMemberStateProvider)?.id;
    final canEdit = board == null || myId == null || board.roleOf(myId) != 'viewer';

    if (!_baselineCaptured) {
      _baselineUpdatedAt = taskDoc?.updatedAt;
      _baselineCaptured = true;
    }

    ConflictInfo? conflict;
    final docUpdatedAt = taskDoc?.updatedAt;
    final docUpdatedBy = taskDoc?.updatedBy;
    if (docUpdatedAt != null &&
        _baselineUpdatedAt != null &&
        docUpdatedAt.isAfter(_baselineUpdatedAt!) &&
        docUpdatedBy != null &&
        docUpdatedBy.id != myId) {
      conflict = ConflictInfo(editedBy: docUpdatedBy, at: docUpdatedAt);
    }

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.modalTop)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 9),
            Container(width: 38, height: 4, decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(3),
            )),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PriorityTag(priority: task.priority),
                        const SizedBox(width: 7),
                        Text(
                          task.column.label,
                          style: AppTextStyles.metaSmall(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        const Spacer(),
                        if (canEdit)
                          Tooltip(
                            message: 'Delete task',
                            child: GestureDetector(
                              onTap: _delete,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('Close', style: AppTextStyles.bodySmall(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ).copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                    if (conflict != null) ...[
                      const SizedBox(height: 12),
                      _ConflictBanner(
                        message: conflict.message,
                        initials: conflict.editedBy.initials,
                        color: conflict.editedBy.color,
                        onDismiss: () => setState(() => _baselineUpdatedAt = docUpdatedAt),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(task.title, style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                        ),
                        const SizedBox(width: 10),
                        if (canEdit)
                          _AiButton(loading: _aiLoading, hasSubtasks: task.subtasks.isNotEmpty, onTap: _runAi),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        MemberAvatar(member: task.assignee, size: 26),
                        const SizedBox(width: 8),
                        Text(task.assignee.name, style: AppTextStyles.bodySmall(
                          color: theme.colorScheme.onSurface,
                        ).copyWith(fontWeight: FontWeight.w600)),
                        if (task.dueDate != null) ...[
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          )),
                          const SizedBox(width: 8),
                          Text(
                            task.isOverdue
                                ? 'Overdue · ${_formatDate(task.dueDate!)}'
                                : task.isDueSoon
                                    ? 'Due soon · ${_formatDate(task.dueDate!)}'
                                    : 'Due ${_formatDate(task.dueDate!)}',
                            style: AppTextStyles.meta(
                              color: task.isOverdue
                                  ? AppColors.priorityHigh
                                  : task.isDueSoon
                                      ? AppColors.priorityMedium
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                            ).copyWith(fontWeight: (task.isOverdue || task.isDueSoon) ? FontWeight.w700 : null),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final l in presetLabelColors.keys)
                          if (canEdit || task.labels.contains(l))
                            _LabelToggle(
                              text: l,
                              selected: task.labels.contains(l),
                              enabled: canEdit,
                              onTap: () {
                                final next = task.labels.contains(l)
                                    ? (List<String>.from(task.labels)..remove(l))
                                    : (List<String>.from(task.labels)..add(l));
                                notifier.setLabels(task.id, next);
                              },
                            ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    task.description.isEmpty
                        ? Text(
                            'No description yet.',
                            style: AppTextStyles.bodyLarge(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ).copyWith(height: 1.6),
                          )
                        : RichTextContent(
                            text: task.description,
                            style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(height: 1.6),
                          ),
                    const SizedBox(height: 14),
                    _AttachmentsRow(
                      task: task,
                      canEdit: canEdit,
                      onAdd: () => _addAttachment(task),
                      onView: (b64) => _viewAttachment(b64, canEdit, task),
                    ),
                    if (_aiLoading) ...[
                      const SizedBox(height: 14),
                      _AiSkeleton(),
                    ],
                    if (task.subtasks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _SubtasksCard(
                        task: task,
                        onToggle: canEdit ? (id) => notifier.toggleSubtask(task.id, id) : null,
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text('COMMENTS', style: AppTextStyles.meta(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                    const SizedBox(height: 10),
                    for (final c in task.comments) ...[
                      _CommentTile(comment: c),
                      const SizedBox(height: 12),
                    ],
                    if (task.activity.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('ACTIVITY', style: AppTextStyles.meta(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                      const SizedBox(height: 10),
                      _ActivityTimeline(entries: task.activity),
                    ],
                  ],
                ),
              ),
            ),
            if (canEdit)
              _CommentInput(
                controller: _commentController,
                onSend: () {
                  notifier.addComment(task.id, _commentController.text, boardMembers: board?.members ?? const []);
                  _commentController.clear();
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
}

class _ConflictBanner extends StatelessWidget {
  final String message;
  final String initials;
  final Color color;
  final VoidCallback onDismiss;
  const _ConflictBanner({required this.message, required this.initials, required this.color, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initials, style: AppTextStyles.metaTiny(color: Colors.white).copyWith(fontSize: 8, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: AppTextStyles.bodySmall(color: AppColors.textPrimaryLight).copyWith(fontWeight: FontWeight.w600, height: 1.35)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text('OK', style: AppTextStyles.bodySmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelToggle extends StatelessWidget {
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _LabelToggle({required this.text, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = labelColor(text);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : theme.dividerColor),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodySmall(
            color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

class _AttachmentsRow extends StatelessWidget {
  final TaskCard task;
  final bool canEdit;
  final VoidCallback onAdd;
  final void Function(String base64Image) onView;
  const _AttachmentsRow({required this.task, required this.canEdit, required this.onAdd, required this.onView});

  @override
  Widget build(BuildContext context) {
    if (task.attachments.isEmpty && !canEdit) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in task.attachments)
          InkWell(
            onTap: () => onView(a),
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(base64Decode(a), width: 56, height: 56, fit: BoxFit.cover),
            ),
          ),
        if (canEdit && task.attachments.length < BoardTasksNotifier.maxAttachments)
          Tooltip(
            message: 'Add attachment',
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          ),
      ],
    );
  }
}

class _AiButton extends StatelessWidget {
  final bool loading;
  final bool hasSubtasks;
  final VoidCallback onTap;
  const _AiButton({required this.loading, required this.hasSubtasks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = loading ? 'Thinking…' : (hasSubtasks ? 'Suggest more' : 'AI subtasks');
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.bodySmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _AiSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (_) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryTintSoft,
          borderRadius: BorderRadius.circular(12),
        ),
      )),
    );
  }
}

class _SubtasksCard extends StatelessWidget {
  final TaskCard task;
  final void Function(String subtaskId)? onToggle;
  const _SubtasksCard({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.subtasks.where((s) => s.done).length;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
            child: Row(
              children: [
                Text('SUGGESTED SUBTASKS', style: AppTextStyles.meta(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                const Spacer(),
                Text('$done / ${task.subtasks.length}', style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
              ],
            ),
          ),
          for (var i = 0; i < task.subtasks.length; i++)
            InkWell(
              onTap: onToggle == null ? null : () => onToggle!(task.subtasks[i].id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  border: i == task.subtasks.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 17, height: 17,
                      decoration: BoxDecoration(
                        color: task.subtasks[i].done ? AppColors.primary : Colors.transparent,
                        border: Border.all(color: task.subtasks[i].done ? AppColors.primary : theme.dividerColor, width: 1.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: task.subtasks[i].done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.subtasks[i].text,
                        style: AppTextStyles.bodySmall(
                          color: theme.colorScheme.onSurface.withValues(alpha: task.subtasks[i].done ? 0.5 : 1),
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: task.subtasks[i].done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final dynamic comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemberAvatar(member: comment.author, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(comment.author.name, style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 7),
                  Text(_formatTime(comment.time), style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
              const SizedBox(height: 3),
              RichTextContent(text: comment.body, style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _ActivityTimeline extends StatelessWidget {
  final List<dynamic> entries;
  const _ActivityTimeline({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 12,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: entries[i].dotColor, shape: BoxShape.circle)),
                      if (i != entries.length - 1)
                        Expanded(child: Container(width: 1, color: theme.dividerColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entries[i].text, style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(height: 1.4)),
                        const SizedBox(height: 2),
                        Text(_formatActivityTime(entries[i].time), style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatActivityTime(DateTime t) {
  final now = DateTime.now();
  final isToday = t.year == now.year && t.month == now.month && t.day == now.day;
  final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return isToday ? 'today $time' : '${t.month}/${t.day} $time';
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _CommentInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 11, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          const _YouAvatar(),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.body(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Add a comment…',
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          GestureDetector(
            onTap: onSend,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text('Send', style: AppTextStyles.bodySmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouAvatar extends StatelessWidget {
  const _YouAvatar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('YOU', style: AppTextStyles.metaTiny(color: Colors.white).copyWith(fontSize: 8, fontWeight: FontWeight.w700)),
    );
  }
}
