import '../models/board_column.dart';

class TaskDragData {
  final String taskId;
  final BoardColumnId fromColumn;
  const TaskDragData({required this.taskId, required this.fromColumn});
}
