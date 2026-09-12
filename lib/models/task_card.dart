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
  });

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
    );
  }
}
