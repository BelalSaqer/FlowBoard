import 'activity_entry.dart';
import 'board_column.dart';
import 'comment.dart';
import 'member.dart';
import 'priority.dart';
import 'subtask.dart';

class TaskCard {
  final String id;
  final String title;
  final String description;
  final Priority priority;
  final Member assignee;
  final DateTime? dueDate;
  final BoardColumnId column;
  final List<SubTask> subtasks;
  final List<TaskComment> comments;
  final List<ActivityEntry> activity;
  final List<String> labels;
  final List<String> attachments;

  const TaskCard({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.assignee,
    required this.column,
    this.dueDate,
    this.subtasks = const [],
    this.comments = const [],
    this.activity = const [],
    this.labels = const [],
    this.attachments = const [],
  });

  bool get isOverdue =>
      dueDate != null && column != BoardColumnId.done && dueDate!.isBefore(DateTime.now());

  bool get isDueSoon =>
      dueDate != null &&
      column != BoardColumnId.done &&
      !isOverdue &&
      dueDate!.difference(DateTime.now()) <= const Duration(days: 2);

  TaskCard copyWith({
    String? title,
    String? description,
    Priority? priority,
    Member? assignee,
    DateTime? dueDate,
    BoardColumnId? column,
    List<SubTask>? subtasks,
    List<TaskComment>? comments,
    List<ActivityEntry>? activity,
    List<String>? labels,
    List<String>? attachments,
  }) {
    return TaskCard(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      assignee: assignee ?? this.assignee,
      dueDate: dueDate ?? this.dueDate,
      column: column ?? this.column,
      subtasks: subtasks ?? this.subtasks,
      comments: comments ?? this.comments,
      activity: activity ?? this.activity,
      labels: labels ?? this.labels,
      attachments: attachments ?? this.attachments,
    );
  }
}
