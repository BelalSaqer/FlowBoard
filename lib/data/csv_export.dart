import '../models/board.dart';
import '../models/board_column.dart';
import '../models/priority.dart';
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

/// One row of a parsed import CSV — deliberately just strings, not a
/// [TaskCard], since resolving "Assignee" text to a real [Member] needs
/// the board's member list, which lives in the provider layer, not here.
class ParsedCsvTask {
  final String title;
  final String description;
  final BoardColumnId column;
  final Priority priority;
  final List<String> labels;
  final String assigneeName;

  const ParsedCsvTask({
    required this.title,
    required this.description,
    required this.column,
    required this.priority,
    required this.labels,
    required this.assigneeName,
  });
}

/// Splits one CSV line into fields, honoring double-quoted fields with
/// `""`-escaped quotes and embedded commas — the exact format
/// [buildBoardCsv] writes, so a round-tripped export/import is lossless
/// for every field this cares about.
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields;
}

BoardColumnId _columnFromLabel(String label) {
  for (final c in BoardColumnId.values) {
    if (c.label.toLowerCase() == label.trim().toLowerCase()) return c;
  }
  return BoardColumnId.todo;
}

Priority _priorityFromLabel(String label) {
  for (final p in Priority.values) {
    if (p.label.toLowerCase() == label.trim().toLowerCase()) return p;
  }
  return Priority.medium;
}

/// Parses a CSV like the one [buildBoardCsv] produces (or a reasonable
/// hand-edited variant — matching is by header name, not position) into
/// importable rows. Only a `Title` column is required; everything else
/// falls back to a sensible default. Throws a [FormatException] with a
/// user-facing message if there's no header row or no `Title` column at
/// all, rather than silently importing nothing.
List<ParsedCsvTask> parseBoardCsv(String csv) {
  final lines = csv.split(RegExp(r'\r\n|\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) {
    throw const FormatException('That file is empty.');
  }
  final header = _parseCsvLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
  final titleIndex = header.indexOf('title');
  if (titleIndex == -1) {
    throw const FormatException('No "Title" column found — expected a header row like the one Export CSV produces.');
  }
  final descIndex = header.indexOf('description');
  final columnIndex = header.indexOf('column');
  final priorityIndex = header.indexOf('priority');
  final labelsIndex = header.indexOf('labels');
  final assigneeIndex = header.indexOf('assignee');

  final rows = <ParsedCsvTask>[];
  for (final line in lines.skip(1)) {
    final fields = _parseCsvLine(line);
    String field(int index) => (index != -1 && index < fields.length) ? fields[index] : '';
    final title = field(titleIndex).trim();
    if (title.isEmpty) continue;
    final labelsRaw = field(labelsIndex).trim();
    rows.add(ParsedCsvTask(
      title: title,
      description: field(descIndex).trim(),
      column: _columnFromLabel(field(columnIndex)),
      priority: _priorityFromLabel(field(priorityIndex)),
      labels: labelsRaw.isEmpty ? const [] : labelsRaw.split(';').map((l) => l.trim()).where((l) => l.isNotEmpty).toList(),
      assigneeName: field(assigneeIndex).trim(),
    ));
  }
  return rows;
}
