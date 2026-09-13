import 'member.dart';

enum NotificationType { comment, assigned, mention }

class NotificationEntry {
  final String id;
  final NotificationType type;
  final Member actor;
  final String taskTitle;
  final String boardId;
  final String taskId;
  final bool read;
  final DateTime createdAt;

  const NotificationEntry({
    required this.id,
    required this.type,
    required this.actor,
    required this.taskTitle,
    required this.boardId,
    required this.taskId,
    required this.read,
    required this.createdAt,
  });

  String get headline => switch (type) {
    NotificationType.comment => '${actor.name} commented on a task assigned to you',
    NotificationType.assigned => '${actor.name} assigned you',
    NotificationType.mention => '${actor.name} mentioned you in a comment',
  };
}
