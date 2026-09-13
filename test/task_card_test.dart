import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/models/board_column.dart';
import 'package:flowboard/models/member.dart';
import 'package:flowboard/models/priority.dart';
import 'package:flowboard/models/task_card.dart';
import 'package:flowboard/theme/app_colors.dart';

const _alice = Member(id: 'alice', name: 'Alice', initials: 'AL', color: AppColors.primary);

TaskCard _task({DateTime? dueDate, BoardColumnId column = BoardColumnId.todo}) => TaskCard(
      id: 't1',
      title: 'Task',
      description: '',
      priority: Priority.medium,
      assignee: _alice,
      column: column,
      dueDate: dueDate,
    );

void main() {
  group('TaskCard due-date status', () {
    test('a past due date on an open task is overdue', () {
      final task = _task(dueDate: DateTime.now().subtract(const Duration(days: 1)));
      expect(task.isOverdue, isTrue);
      expect(task.isDueSoon, isFalse);
    });

    test('a due date within 2 days is due soon, not overdue', () {
      final task = _task(dueDate: DateTime.now().add(const Duration(hours: 20)));
      expect(task.isOverdue, isFalse);
      expect(task.isDueSoon, isTrue);
    });

    test('a due date far in the future is neither overdue nor due soon', () {
      final task = _task(dueDate: DateTime.now().add(const Duration(days: 30)));
      expect(task.isOverdue, isFalse);
      expect(task.isDueSoon, isFalse);
    });

    test('a task already in Done is never overdue, even with a past due date', () {
      final task = _task(
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
        column: BoardColumnId.done,
      );
      expect(task.isOverdue, isFalse);
      expect(task.isDueSoon, isFalse);
    });

    test('no due date means neither overdue nor due soon', () {
      final task = _task();
      expect(task.isOverdue, isFalse);
      expect(task.isDueSoon, isFalse);
    });
  });
}
