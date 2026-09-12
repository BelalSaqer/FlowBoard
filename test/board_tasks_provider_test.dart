import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/models/board_column.dart';
import 'package:flowboard/models/member.dart';
import 'package:flowboard/providers/board_tasks_provider.dart';
import 'package:flowboard/theme/app_colors.dart';

const _alice = Member(id: 'alice', name: 'Alice', initials: 'AL', color: AppColors.primary);
const _bob = Member(id: 'bob', name: 'Bob', initials: 'BO', color: AppColors.priorityHigh);

BoardTasksNotifier _notifier(FakeFirebaseFirestore db, {Member current = _alice}) {
  return BoardTasksNotifier(db, 'board-1', () => current);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('BoardTasksNotifier', () {
    test('addTask assigns increasing fractional order within a column', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();

      await notifier.addTask(BoardColumnId.todo, 'First');
      await notifier.addTask(BoardColumnId.todo, 'Second');
      await _settle();

      final tasks = notifier.state[BoardColumnId.todo]!;
      expect(tasks.map((t) => t.title), ['First', 'Second']);
      final firstOrder = notifier.taskDocById(tasks[0].id)!.order;
      final secondOrder = notifier.taskDocById(tasks[1].id)!.order;
      expect(secondOrder, greaterThan(firstOrder));
    });

    test('moveTask reorders via a fractional index between siblings', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();

      await notifier.addTask(BoardColumnId.todo, 'A');
      await notifier.addTask(BoardColumnId.todo, 'B');
      await notifier.addTask(BoardColumnId.todo, 'C');
      await _settle();

      final ids = notifier.state[BoardColumnId.todo]!.map((t) => t.id).toList();
      // Move C (last) to index 0 — should land before A, with a lower order.
      await notifier.moveTask(taskId: ids[2], toColumn: BoardColumnId.todo, toIndex: 0);
      await _settle();

      final reordered = notifier.state[BoardColumnId.todo]!;
      expect(reordered.first.title, 'C');
      final cOrder = notifier.taskDocById(ids[2])!.order;
      final aOrder = notifier.taskDocById(ids[0])!.order;
      expect(cOrder, lessThan(aOrder));
    });

    test('moveTask stamps updatedBy with the mover, not the original author', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db, current: _alice);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'Task');
      await _settle();
      final id = notifier.state[BoardColumnId.todo]!.first.id;

      final asBob = _notifier(db, current: _bob);
      await asBob.moveTask(taskId: id, toColumn: BoardColumnId.inProgress, toIndex: 0);
      await _settle();

      final doc = await db.collection('boards').doc('board-1').collection('tasks').doc(id).get();
      expect(doc.data()!['updatedBy']['id'], 'bob');
      expect(doc.data()!['column'], 'inProgress');
    });

    test('addTask notifies the assignee but not the creator when assigning to someone else', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db, current: _alice);
      await _settle();

      await notifier.addTask(BoardColumnId.todo, 'For Bob', assignee: _bob);
      await _settle();

      final bobNotifs = await db.collection('users').doc('bob').collection('notifications').get();
      final aliceNotifs = await db.collection('users').doc('alice').collection('notifications').get();
      expect(bobNotifs.docs, hasLength(1));
      expect(aliceNotifs.docs, isEmpty);
    });

    test('addTask does not notify yourself when self-assigned', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db, current: _alice);
      await _settle();

      await notifier.addTask(BoardColumnId.todo, 'For myself');
      await _settle();

      final aliceNotifs = await db.collection('users').doc('alice').collection('notifications').get();
      expect(aliceNotifs.docs, isEmpty);
    });

    test('toggleSubtask flips done state', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'Task');
      await _settle();
      final id = notifier.state[BoardColumnId.todo]!.first.id;

      await db.collection('boards').doc('board-1').collection('tasks').doc(id).update({
        'subtasks': [
          {'id': 's1', 'text': 'Step 1', 'done': false},
        ],
      });
      await _settle();

      await notifier.toggleSubtask(id, 's1');
      await _settle();

      expect(notifier.taskById(id)!.subtasks.first.done, isTrue);
    });

    test('deleteTask removes the task document', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'Task');
      await _settle();
      final id = notifier.state[BoardColumnId.todo]!.first.id;

      await notifier.deleteTask(id);
      await _settle();

      expect(notifier.state[BoardColumnId.todo], isEmpty);
      final doc = await db.collection('boards').doc('board-1').collection('tasks').doc(id).get();
      expect(doc.exists, isFalse);
    });
  });
}
