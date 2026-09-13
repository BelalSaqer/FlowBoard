import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/data/csv_export.dart';
import 'package:flowboard/models/board.dart';
import 'package:flowboard/models/board_column.dart';
import 'package:flowboard/models/member.dart';
import 'package:flowboard/models/priority.dart';
import 'package:flowboard/models/task_card.dart';
import 'package:flowboard/theme/app_colors.dart';

const _alice = Member(id: 'alice', name: 'Alice', initials: 'AL', color: AppColors.primary);

Board _board() => Board(
      id: 'b1',
      name: 'Test Board',
      color: AppColors.primary,
      members: const [_alice],
      updatedAt: DateTime(2026, 1, 1),
      ownerId: 'alice',
    );

void main() {
  test('buildBoardCsv emits a header row plus one row per task, quoting fields with commas', () {
    final tasks = {
      BoardColumnId.todo: [
        const TaskCard(
          id: 't1',
          title: 'Fix, the bug',
          description: 'desc',
          priority: Priority.high,
          assignee: _alice,
          column: BoardColumnId.todo,
          labels: ['Bug', 'Urgent'],
        ),
      ],
      BoardColumnId.inProgress: const <TaskCard>[],
      BoardColumnId.done: const <TaskCard>[],
    };

    final csv = buildBoardCsv(_board(), tasks);
    final lines = csv.split('\r\n');

    expect(lines, hasLength(2));
    expect(lines[0], startsWith('"Title","Description"'));
    expect(lines[1], contains('"Fix, the bug"'));
    expect(lines[1], contains('"Bug; Urgent"'));
    expect(lines[1], contains('"High"'));
  });

  test('buildBoardCsv produces only the header row for an empty board', () {
    final csv = buildBoardCsv(_board(), {
      BoardColumnId.todo: const [],
      BoardColumnId.inProgress: const [],
      BoardColumnId.done: const [],
    });
    expect(csv.split('\r\n'), hasLength(1));
  });
}
