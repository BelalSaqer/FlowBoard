import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/csv_export.dart';
import '../models/board.dart';
import '../models/board_column.dart';
import '../models/task_card.dart';
import '../providers/board_tasks_provider.dart';
import '../providers/boards_provider.dart';
import '../providers/profile_provider.dart';
import '../services/file_export.dart';
import '../services/file_import.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_back_button.dart';
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

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // showModalBottomSheet keeps this route's widgets reachable by the key
  // dispatch chain even while the sheet is on top and its own TextField
  // has focus — unlike a full Navigator.push, it doesn't fully deactivate
  // the page underneath. That's what let 'n'/'/' hijack keystrokes typed
  // into a sheet's title/comment field even with CallbackShortcuts (which
  // otherwise correctly respects focused-field consumption). Tracking
  // "a sheet is open" explicitly and gating the shortcuts on it sidesteps
  // that entirely, and is arguably the more correct behavior anyway —
  // 'n' shouldn't open a second new-task sheet over the first one.
  bool _sheetOpen = false;

  Future<T?> _showSheet<T>(WidgetBuilder builder) async {
    setState(() => _sheetOpen = true);
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
    if (mounted) setState(() => _sheetOpen = false);
    return result;
  }

  void _newTaskShortcut() {
    if (_sheetOpen) return;
    final myId = ref.read(currentMemberStateProvider)?.id;
    final board = ref.read(boardsProvider).firstWhere((b) => b.id == widget.board.id, orElse: () => widget.board);
    final isViewer = myId != null && board.roleOf(myId) == 'viewer';
    if (!isViewer) _openNewTask(_columns[_activeColumn]);
  }

  void _searchShortcut() {
    if (_sheetOpen) return;
    final board = ref.read(boardsProvider).firstWhere((b) => b.id == widget.board.id, orElse: () => widget.board);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(board: board)));
  }

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
    _showSheet((_) => TaskDetailSheet(boardId: widget.board.id, taskId: task.id));
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String taskId) {
    setState(() {
      if (_selectedIds.contains(taskId)) {
        _selectedIds.remove(taskId);
      } else {
        _selectedIds.add(taskId);
      }
    });
  }

  Future<void> _bulkMove(BoardColumnId toColumn) async {
    final ids = Set<String>.from(_selectedIds);
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    await ref.read(boardTasksProvider(widget.board.id).notifier).bulkMove(ids, toColumn);
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count task${count == 1 ? '' : 's'}?'),
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
    final ids = Set<String>.from(_selectedIds);
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    await ref.read(boardTasksProvider(widget.board.id).notifier).bulkDelete(ids);
  }

  void _exportCsv(Board board) {
    final tasksByColumn = ref.read(boardTasksProvider(board.id));
    final csv = buildBoardCsv(board, tasksByColumn);
    final filename = '${board.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')}_export.csv';
    final ok = downloadTextFile(filename, csv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Downloaded $filename' : 'Export is only available on web.')),
    );
  }

  Future<void> _importCsv(Board board) async {
    // Fires with no `await` before it, same gesture-timing requirement as
    // the avatar photo picker — pickTextFile's own first statement is the
    // browser file-dialog call.
    final text = await pickTextFile(accept: '.csv,text/csv');
    if (text == null || !mounted) return;
    try {
      final rows = parseBoardCsv(text);
      if (rows.isEmpty) {
        throw const FormatException('No task rows with a Title were found in that file.');
      }
      final count = await ref.read(boardTasksProvider(board.id).notifier).bulkImportTasks(rows, board.members);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count task${count == 1 ? '' : 's'}.')),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openNewTask(BoardColumnId column) {
    final me = ref.read(currentMemberStateProvider);
    if (me == null) return;
    final board = ref.read(boardsProvider).firstWhere(
          (b) => b.id == widget.board.id,
          orElse: () => widget.board,
        );
    if (board.roleOf(me.id) == 'viewer') return;
    _showSheet((_) => NewTaskSheet(
          boardId: widget.board.id,
          initialColumn: column,
          members: board.members,
          currentMember: me,
        ));
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
    final myId = ref.watch(currentMemberStateProvider)?.id;
    final isViewer = myId != null && board.roleOf(myId) == 'viewer';

    // CallbackShortcuts (not a raw HardwareKeyboard hook, which fires
    // unconditionally regardless of focus). On Flutter web, a focused
    // EditableText doesn't reliably mark plain character keys as
    // "handled" — browser-side text composition inserts the character,
    // but the key event can still bubble to an ancestor Shortcuts/
    // CallbackShortcuts — so the real guard against hijacking keystrokes
    // while typing is the explicit _sheetOpen check inside
    // _newTaskShortcut/_searchShortcut, not this widget's focus handling
    // by itself.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): _newTaskShortcut,
        const SingleActivator(LogicalKeyboardKey.slash): _searchShortcut,
      },
      child: Scaffold(
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
                      AppBackButton(onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(board.name, style: AppTextStyles.h2(color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis),
                                ),
                                if (isViewer) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text('VIEW ONLY', style: AppTextStyles.metaTiny(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                    ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                                  ),
                                ],
                              ],
                            ),
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
                      if (!isViewer && !isEmpty) ...[
                        const SizedBox(width: 8),
                        _SelectModeButton(active: _selectionMode, onTap: _toggleSelectionMode),
                      ],
                      const SizedBox(width: 8),
                      _OverflowButton(
                        showInviteAndSettings: !isViewer,
                        onSelected: (value) {
                          if (value == 'invite') {
                            _showSheet((_) => InviteSheet(board: board));
                          } else if (value == 'activity') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ActivityScreen(board: board)),
                            );
                          } else if (value == 'settings') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => BoardSettingsScreen(board: board)),
                            );
                          } else if (value == 'export') {
                            _exportCsv(board);
                          } else if (value == 'import') {
                            _importCsv(board);
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
                  onAddFirstTask: isViewer ? null : () => _openNewTask(BoardColumnId.todo),
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
                      canEdit: !isViewer,
                      selectionMode: _selectionMode,
                      selectedTaskIds: _selectedIds,
                      onToggleSelect: _toggleSelect,
                    );
                  },
                ),
              ),
            ),
            ],
            if (_selectionMode && _selectedIds.isNotEmpty)
              _BulkActionBar(
                count: _selectedIds.length,
                onMove: _bulkMove,
                onDelete: _bulkDelete,
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SelectModeButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _SelectModeButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: active ? 'Exit selection mode' : 'Select multiple tasks',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : theme.colorScheme.surface,
            border: Border.all(color: active ? AppColors.primary : theme.dividerColor),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            Icons.checklist,
            size: 18,
            color: active ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  final int count;
  final void Function(BoardColumnId) onMove;
  final VoidCallback onDelete;
  const _BulkActionBar({required this.count, required this.onMove, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text(
            '$count selected',
            style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          PopupMenuButton<BoardColumnId>(
            tooltip: 'Move to',
            onSelected: onMove,
            itemBuilder: (context) => [
              for (final c in BoardColumnId.values) PopupMenuItem(value: c, child: Text('Move to ${c.label}')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Move to', style: AppTextStyles.bodySmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.priorityHighBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Delete', style: AppTextStyles.bodySmall(color: AppColors.priorityHigh).copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
    return Tooltip(
      message: 'Search tasks (/)',
      child: InkWell(
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
      ),
    );
  }
}

class _OverflowButton extends StatelessWidget {
  final void Function(String value) onSelected;
  final bool showInviteAndSettings;
  const _OverflowButton({required this.onSelected, this.showInviteAndSettings = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Board menu',
      offset: const Offset(0, 42),
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (showInviteAndSettings) const PopupMenuItem(value: 'invite', child: Text('Invite')),
        const PopupMenuItem(value: 'activity', child: Text('Activity')),
        const PopupMenuItem(value: 'export', child: Text('Export CSV')),
        if (showInviteAndSettings) const PopupMenuItem(value: 'import', child: Text('Import CSV')),
        if (showInviteAndSettings) const PopupMenuItem(value: 'settings', child: Text('Board settings')),
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
