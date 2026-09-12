import 'member.dart';

class TaskComment {
  final String id;
  final Member author;
  final DateTime time;
  final String body;

  const TaskComment({
    required this.id,
    required this.author,
    required this.time,
    required this.body,
  });
}
