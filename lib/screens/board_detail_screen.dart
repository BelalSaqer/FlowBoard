import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import '../models/board_column.dart';
import '../models/task_card.dart';
import '../providers/board_tasks_provider.dart';
import '../providers/boards_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_text_styles.dart';
import '../widgets/board_column_view.dart';
import '../widgets/empty_states.dart';
import '../widgets/new_task_sheet.dart';
import '../widgets/presence_bar.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/task_drag_data.dart';
import 'activity_screen.dart';
import 'auth_gate.dart';
import 'board_settings_screen.dart';
import 'search_screen.dart';
import 'task_detail_sheet.dart';

const _columnWidth = 272.0;
const _columnGap = 12.0;

class BoardDetailScreen extends ConsumerStatefulWidget {
  final Board board;
  const BoardDetailScreen({super.key, required this.board});

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  final _scrollController = ScrollController();
  int _activeColumn = 0;

  bool _isDragging = false;
  BoardColumnId? _hoverColumn;
  int? _hoverIndex;
  Timer? _autoScrollTimer;

  static const _columns = BoardColumnId.values;

  PresenceHeartbeat? _heartbeat;

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentMemberStateProvider);
    if (me != null) {
      _heartbeat = PresenceHeartbeat(
        db: ref.read(firestoreProvider),
        boardId: widget.board.id,
        member: me,
      )..start();
    }
  }

  @override
  void dispose() {
    _heartbeat?.stop();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onBoardScroll() {
    final i = (_scrollController.offset / (_columnWidth + _columnGap))
        .round()
        .clamp(0, _columns.length - 1);
    if (i != _activeColumn) setState(() => _activeColumn = i);
  }

  void _goToColumn(int i) {
    _scrollController.animateTo(
      i * (_columnWidth + _columnGap),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    setState(() => _activeColumn = i);
  }

  void _onDragStarted(TaskDragData data) {
    setState(() => _isDragging = true);
  }

  void _onDragEnd() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    setState(() {
      _isDragging = false;
      _hoverColumn = null;
      _hoverIndex = null;
    });
  }

  void _onHover(TaskDragData data, int index, BoardColumnId column) {
    if (_hoverColumn != column || _hoverIndex != index) {
      setState(() {
        _hoverColumn = column;
        _hoverIndex = index;
      });
    }
  }

  void _onDrop(TaskDragData data, BoardColumnId column, int fallbackIndex) {
    final index = (_hoverColumn == column ? _hoverIndex : null) ?? fallbackIndex;
    ref
        .read(boardTasksProvider(widget.board.id).notifier)
        .moveTask(taskId: data.taskId, toColumn: column, toIndex: index);
    _onDragEnd();
  }

  void _onDragUpdateGlobal(DragUpdateDetails details) {
    final width = MediaQuery.of(context).size.width;
    const edge = 70.0;
    final x = details.globalPosition.dx;
    if (x < edge) {
      _startAutoScroll(-1);
    } else if (x > width - edge) {
      _startAutoScroll(1);
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  void _startAutoScroll(int direction) {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final next = (_scrollController.offset + direction * 8).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(next);
    });
  }

  void _openTask(TaskCard task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailSheet(boardId: widget.board.id, taskId: task.id),
    );
  }

  void _openNewTask(BoardColumnId column) {
    final me = ref.read(currentMemberStateProvider);
    if (me == null) return;
    final board = ref.read(boardsProvider).firstWhere(
          (b) => b.id == widget.board.id,
          orElse: () => widget.board,
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewTaskSheet(
        boardId: widget.board.id,
        initialColumn: column,
        members: board.members,
        currentMember: me,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = ref.watch(boardsProvider).firstWhere(
          (b) => b.id == widget.board.id,
          orElse: () => widget.board,
        );
    final tasksByColumn = ref.watch(boardTasksProvider(widget.board.id));
    final presence = ref.watch(presenceProvider(widget.board.id));
    final total = tasksByColumn.values.fold<int>(0, (a, l) => a + l.length);
    final isEmpty = total == 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BackButton(onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(board.name, style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 2),
                            Text(
                              isEmpty
                                  ? '0 tasks · ${_columns.length} columns'
                                  : '$total tasks · updated ${_relativeTime(board.updatedAt)}',
                              style: AppTextStyles.metaMedium(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _SearchButton(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SearchScreen(board: board)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _OverflowButton(
                        onSelected: (value) {
                          if (value == 'invite') {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => InviteSheet(board: board),
                            );
                          } else if (value == 'activity') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ActivityScreen(board: board)),
                            );
                          } else if (value == 'settings') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => BoardSettingsScreen(board: board)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (!isEmpty) ...[
                    const SizedBox(height: 12),
                    PresenceBar(viewers: presence),
                  ],
                ],
              ),
            ),
            if (isEmpty)
              Expanded(
                child: BoardTasksEmptyState(
                  onAddFirstTask: () => _openNewTask(BoardColumnId.todo),
                ),
              )
            else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: IgnorePointer(
                ignoring: _isDragging,
                child: Row(
                children: [
                  for (var i = 0; i < _columns.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == _columns.length - 1 ? 0 : 5),
                        child: _ColumnTab(
                          label: _columns[i].label,
                          active: i == _activeColumn,
                          onTap: () => _goToColumn(i),
                        ),
                      ),
                    ),
                ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  _onBoardScroll();
                  return false;
                },
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                  itemCount: _columns.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _columnGap),
                  itemBuilder: (context, i) {
                    final columnId = _columns[i];
                    return BoardColumnView(
                      columnId: columnId,
                      tasks: tasksByColumn[columnId] ?? const [],
                      width: _columnWidth,
                      hoverColumn: _hoverColumn,
                      hoverIndex: _hoverIndex,
                      onHover: _onHover,
                      onDrop: _onDrop,
                      onDragStarted: _onDragStarted,
                      onDragEnd: _onDragEnd,
                      onDragUpdateGlobal: _onDragUpdateGlobal,
                      onOpenTask: _openTask,
                      onOpenNewTask: _openNewTask,
                    );
                  },
                ),
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchButton({required this.onTap});

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
        child: Icon(Icons.search, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}

class _OverflowButton extends StatelessWidget {
  final void Function(String value) onSelected;
  const _OverflowButton({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Board menu',
      offset: const Offset(0, 42),
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'invite', child: Text('Invite')),
        PopupMenuItem(value: 'activity', child: Text('Activity')),
        PopupMenuItem(value: 'settings', child: Text('Board settings')),
      ],
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(Icons.more_horiz, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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

class _ColumnTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ColumnTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.surface : Colors.transparent,
          border: Border.all(color: active ? theme.dividerColor : Colors.transparent),
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.metaSmall(
            color: active
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
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
