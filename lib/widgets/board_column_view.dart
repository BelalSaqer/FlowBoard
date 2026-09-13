import 'package:flutter/material.dart';
import '../models/board_column.dart';
import '../models/task_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'task_card_widget.dart';
import 'task_drag_data.dart';

const _columnDotColors = {
  BoardColumnId.todo: AppColors.textFaintLight,
  BoardColumnId.inProgress: AppColors.primary,
  BoardColumnId.done: AppColors.priorityLowAlt,
};

class BoardColumnView extends StatelessWidget {
  final BoardColumnId columnId;
  final List<TaskCard> tasks;
  final double width;
  final BoardColumnId? hoverColumn;
  final int? hoverIndex;
  final void Function(TaskDragData data, int index, BoardColumnId column)
  onHover;
  final void Function(TaskDragData data, BoardColumnId column, int index)
  onDrop;
  final void Function(TaskDragData data) onDragStarted;
  final VoidCallback onDragEnd;
  final void Function(DragUpdateDetails details) onDragUpdateGlobal;
  final void Function(TaskCard task) onOpenTask;
  final void Function(BoardColumnId column) onOpenNewTask;
  final bool canEdit;
  final bool selectionMode;
  final Set<String> selectedTaskIds;
  final void Function(String taskId)? onToggleSelect;

  const BoardColumnView({
    super.key,
    required this.columnId,
    required this.tasks,
    required this.width,
    required this.hoverColumn,
    required this.hoverIndex,
    required this.onHover,
    required this.onDrop,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDragUpdateGlobal,
    required this.onOpenTask,
    required this.onOpenNewTask,
    this.canEdit = true,
    this.selectionMode = false,
    this.selectedTaskIds = const {},
    this.onToggleSelect,
  });

  bool get _isHoverTarget => hoverColumn == columnId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _columnDotColors[columnId],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  columnId.label.toUpperCase(),
                  style: AppTextStyles.bodySmall(
                    color: theme.colorScheme.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: AppTextStyles.meta(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? _EmptyColumnTarget(
                    columnId: columnId,
                    isHovering: _isHoverTarget,
                    onHover: onHover,
                    onDrop: onDrop,
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        _Gap(show: _isHoverTarget && hoverIndex == i),
                        _CardSlot(
                          task: tasks[i],
                          index: i,
                          columnId: columnId,
                          canDrag: canEdit && !selectionMode,
                          onHover: onHover,
                          onDrop: onDrop,
                          onDragStarted: onDragStarted,
                          onDragEnd: onDragEnd,
                          onDragUpdateGlobal: onDragUpdateGlobal,
                          onOpenTask: selectionMode ? (t) => onToggleSelect?.call(t.id) : onOpenTask,
                          selectionMode: selectionMode,
                          selected: selectedTaskIds.contains(tasks[i].id),
                        ),
                        const SizedBox(height: 9),
                      ],
                      _Gap(show: _isHoverTarget && hoverIndex == tasks.length),
                      _TrailingTarget(
                        columnId: columnId,
                        endIndex: tasks.length,
                        onHover: onHover,
                        onDrop: onDrop,
                      ),
                    ],
                  ),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _AddTaskButton(
                onTap: () => onOpenNewTask(columnId),
              ),
            ),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  final bool show;
  const _Gap({required this.show});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: show ? 10 : 0,
      margin: EdgeInsets.symmetric(vertical: show ? 3 : 0),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _CardSlot extends StatelessWidget {
  final TaskCard task;
  final int index;
  final BoardColumnId columnId;
  final void Function(TaskDragData data, int index, BoardColumnId column)
  onHover;
  final void Function(TaskDragData data, BoardColumnId column, int index)
  onDrop;
  final void Function(TaskDragData data) onDragStarted;
  final VoidCallback onDragEnd;
  final void Function(DragUpdateDetails details) onDragUpdateGlobal;
  final void Function(TaskCard task) onOpenTask;
  final bool canDrag;
  final bool selectionMode;
  final bool selected;

  const _CardSlot({
    required this.task,
    required this.index,
    required this.columnId,
    required this.onHover,
    required this.onDrop,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDragUpdateGlobal,
    required this.onOpenTask,
    this.canDrag = true,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = TaskDragData(taskId: task.id, fromColumn: task.column);

    if (selectionMode) {
      return Stack(
        children: [
          Opacity(
            opacity: selected ? 0.55 : 1,
            child: TaskCardWidget(task: task, onTap: () => onOpenTask(task)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? AppColors.primary : Theme.of(context).dividerColor, width: 1.6),
                ),
                child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
          ),
        ],
      );
    }

    if (!canDrag) {
      return TaskCardWidget(task: task, onTap: () => onOpenTask(task));
    }

    return DragTarget<TaskDragData>(
      onWillAcceptWithDetails: (details) => details.data.taskId != task.id,
      onMove: (details) {
        final box = context.findRenderObject();
        if (box is RenderBox) {
          final local = box.globalToLocal(details.offset);
          final isTopHalf = local.dy < box.size.height / 2;
          onHover(details.data, isTopHalf ? index : index + 1, columnId);
        }
      },
      onAcceptWithDetails: (details) {
        onDrop(details.data, columnId, index);
      },
      builder: (context, candidates, rejected) {
        return LongPressDraggable<TaskDragData>(
          data: data,
          delay: const Duration(milliseconds: 220),
          onDragStarted: () => onDragStarted(data),
          onDragUpdate: onDragUpdateGlobal,
          onDragEnd: (_) => onDragEnd(),
          onDraggableCanceled: (_, _) => onDragEnd(),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 262,
              child: Transform.rotate(
                angle: 0.02,
                child: TaskCardWidget(task: task),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: TaskCardWidget(task: task),
          ),
          child: TaskCardWidget(task: task, onTap: () => onOpenTask(task)),
        );
      },
    );
  }
}

class _TrailingTarget extends StatelessWidget {
  final BoardColumnId columnId;
  final int endIndex;
  final void Function(TaskDragData data, int index, BoardColumnId column)
  onHover;
  final void Function(TaskDragData data, BoardColumnId column, int index)
  onDrop;

  const _TrailingTarget({
    required this.columnId,
    required this.endIndex,
    required this.onHover,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<TaskDragData>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (details) => onHover(details.data, endIndex, columnId),
      onAcceptWithDetails: (details) =>
          onDrop(details.data, columnId, endIndex),
      builder: (context, candidates, rejected) =>
          SizedBox(height: candidates.isNotEmpty ? 56 : 32, width: double.infinity),
    );
  }
}

class _EmptyColumnTarget extends StatelessWidget {
  final BoardColumnId columnId;
  final bool isHovering;
  final void Function(TaskDragData data, int index, BoardColumnId column)
  onHover;
  final void Function(TaskDragData data, BoardColumnId column, int index)
  onDrop;

  const _EmptyColumnTarget({
    required this.columnId,
    required this.isHovering,
    required this.onHover,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<TaskDragData>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (details) => onHover(details.data, 0, columnId),
      onAcceptWithDetails: (details) => onDrop(details.data, columnId, 0),
      builder: (context, candidates, rejected) {
        final active = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : theme.dividerColor,
              style: BorderStyle.solid,
              width: active ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(15),
            color: active ? AppColors.primaryTintSoft : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                columnId.emptyLabel,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Drag a card here or add one below.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ).copyWith(height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTaskButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          '+ Add task',
          style: AppTextStyles.bodySmall(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
