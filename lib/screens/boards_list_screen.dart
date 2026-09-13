import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/board_templates.dart';
import '../providers/board_tasks_provider.dart';
import '../providers/boards_provider.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../providers/notifications_provider.dart';
import '../widgets/board_card.dart';
import '../widgets/empty_states.dart';
import '../widgets/member_avatar.dart';
import 'archived_boards_screen.dart';
import 'auth_gate.dart';
import 'board_detail_screen.dart';
import 'my_tasks_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class BoardsListScreen extends ConsumerWidget {
  const BoardsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final boards = ref.watch(boardsProvider);
    final shared = boards.length - 1;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('Boards', style: AppTextStyles.h1(color: theme.colorScheme.onSurface)),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    return Tooltip(
                      message: 'New board',
                      child: InkWell(
                        onTap: () => _showCreateBoardDialog(context, ref),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    return Tooltip(
                      message: 'My Tasks',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyTasksScreen()),
                        ),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(color: theme.dividerColor),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.checklist_rtl, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                      ),
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
                    return Tooltip(
                      message: unread > 0 ? 'Notifications ($unread unread)' : 'Notifications',
                      child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.dividerColor),
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Icon(Icons.notifications_outlined, size: 19, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                            if (unread > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppColors.priorityHigh,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                  child: Text(
                                    '$unread',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final me = ref.watch(currentMemberStateProvider);
                    if (me == null) return const SizedBox.shrink();
                    return Tooltip(
                      message: 'Your profile',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        ),
                        child: MemberAvatar(member: me, size: 36),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (boards.isEmpty)
              BoardsEmptyState(
                onCreateBoard: () => _showCreateBoardDialog(context, ref),
                onJoinWithLink: () => _showJoinByLinkDialog(context, ref),
              )
            else ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${boards.length} boards · $shared shared with you',
                      style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ArchivedBoardsScreen()),
                    ),
                    child: Text(
                      'Archived',
                      style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.45)).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final board in boards) ...[
                Consumer(
                  builder: (context, ref, _) {
                    final tasks = ref.watch(boardTasksProvider(board.id));
                    final presence = ref.watch(presenceProvider(board.id));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: BoardCard(
                        board: board,
                        tasksByColumn: tasks,
                        liveCount: presence.length,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => BoardDetailScreen(board: board)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateBoardDialog(BuildContext context, WidgetRef ref) {
    final me = ref.read(currentMemberStateProvider);
    if (me == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _CreateBoardDialog(creator: me),
    );
  }

  void _showJoinByLinkDialog(BuildContext context, WidgetRef ref) {
    final me = ref.read(currentMemberStateProvider);
    if (me == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _JoinByLinkDialog(me: me),
    );
  }
}

/// Extracts a board id from either a full invite link
/// (`https://.../join/{id}`, with or without scheme) or a bare id pasted
/// directly, so this works whether someone pastes the whole URL Copy
/// Link gave them or just the id at the end of it.
String? _parseBoardIdFromInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final joinIndex = trimmed.indexOf('/join/');
  if (joinIndex != -1) {
    final rest = trimmed.substring(joinIndex + '/join/'.length);
    final id = rest.split(RegExp(r'[/?#]')).first.trim();
    return id.isEmpty ? null : id;
  }
  return trimmed;
}

class _JoinByLinkDialog extends ConsumerStatefulWidget {
  final Member me;
  const _JoinByLinkDialog({required this.me});

  @override
  ConsumerState<_JoinByLinkDialog> createState() => _JoinByLinkDialogState();
}

class _JoinByLinkDialogState extends ConsumerState<_JoinByLinkDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final boardId = _parseBoardIdFromInput(_controller.text);
    if (boardId == null) {
      setState(() => _error = 'Paste an invite link to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final board = await ref.read(boardsProvider.notifier).joinBoardByLink(boardId, widget.me);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoardDetailScreen(board: board)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is StateError ? e.message : 'That link doesn\'t look right — check it and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Join with an invite link', style: AppTextStyles.h3(color: theme.colorScheme.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface),
            decoration: const InputDecoration(hintText: 'flowboard-app-7539.web.app/join/...'),
            onSubmitted: (_) => _join(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppTextStyles.bodySmall(color: AppColors.priorityHigh)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _join,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}

class _CreateBoardDialog extends ConsumerStatefulWidget {
  final Member creator;
  const _CreateBoardDialog({required this.creator});

  @override
  ConsumerState<_CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends ConsumerState<_CreateBoardDialog> {
  final _controller = TextEditingController();
  Color _color = AppColors.primary;
  BoardTemplate _template = boardTemplates.first;
  bool _submitting = false;

  static const _palette = [
    AppColors.primary,
    AppColors.priorityHigh,
    AppColors.priorityMedium,
    AppColors.priorityLow,
    AppColors.accentPink,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await ref
        .read(boardsProvider.notifier)
        .createBoard(_controller.text, _color, widget.creator, templateTasks: _template.tasks);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('New board', style: AppTextStyles.h3(color: theme.colorScheme.onSurface)),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface),
            decoration: const InputDecoration(hintText: 'Board name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final c in _palette)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _color = c),
                    borderRadius: BorderRadius.circular(AppRadii.avatar),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: _color == c ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'STARTING POINT',
            style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),
          for (final t in boardTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => setState(() => _template = t),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _template == t ? AppColors.primaryTint : theme.colorScheme.onSurface.withValues(alpha: 0.04),
                    border: Border.all(color: _template == t ? AppColors.primary : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        t.description,
                        style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
