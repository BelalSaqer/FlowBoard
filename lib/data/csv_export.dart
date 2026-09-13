import '../models/board.dart';
import '../models/board_column.dart';
import '../models/task_card.dart';

String _csvField(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

/// Builds a CSV export of every task on [board], one row per task, in a
/// spreadsheet-friendly column order. Pure string building — no I/O here,
/// so it's usable from both the web download path and, if ever needed,
/// a test that just checks the generated text.
String buildBoardCsv(Board board, Map<BoardColumnId, List<TaskCard>> tasksByColumn) {
  final rows = <String>[
    [
      'Title',
      'Description',
      'Column',
      'Priority',
      'Labels',
      'Assignee',
      'Due date',
      'Subtasks done',
      'Subtasks total',
      'Comments',
    ].map(_csvField).join(','),
  ];

  for (final column in BoardColumnId.values) {
    for (final task in tasksByColumn[column] ?? const <TaskCard>[]) {
      final doneSubtasks = task.subtasks.where((s) => s.done).length;
      rows.add([
        task.title,
        task.description,
        column.label,
        task.priority.label,
        task.labels.join('; '),
        task.assignee.name,
        task.dueDate == null ? '' : '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}',
        '$doneSubtasks',
        '${task.subtasks.length}',
        '${task.comments.length}',
      ].map(_csvField).join(','));
    }
  }

  return rows.join('\r\n');
}
