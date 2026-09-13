import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/data/csv_export.dart';
import 'package:flowboard/models/board_column.dart';
import 'package:flowboard/models/member.dart';
import 'package:flowboard/models/priority.dart';
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

    test('addTask persists labels and setLabels overwrites them', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'Task', labels: ['Bug', 'Urgent']);
      await _settle();
      final id = notifier.state[BoardColumnId.todo]!.first.id;
      expect(notifier.taskById(id)!.labels, ['Bug', 'Urgent']);

      await notifier.setLabels(id, ['Design']);
      await _settle();
      expect(notifier.taskById(id)!.labels, ['Design']);
    });

    test('bulkMove moves every selected task into the target column', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'A');
      await notifier.addTask(BoardColumnId.todo, 'B');
      await notifier.addTask(BoardColumnId.inProgress, 'C');
      await _settle();
      final ids = notifier.state[BoardColumnId.todo]!.map((t) => t.id).toSet();

      await notifier.bulkMove(ids, BoardColumnId.done);
      await _settle();

      expect(notifier.state[BoardColumnId.todo], isEmpty);
      expect(notifier.state[BoardColumnId.done]!.map((t) => t.title).toSet(), {'A', 'B'});
      expect(notifier.state[BoardColumnId.inProgress]!.map((t) => t.title), ['C']);
    });

    test('bulkDelete removes every selected task', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'A');
      await notifier.addTask(BoardColumnId.todo, 'B');
      await notifier.addTask(BoardColumnId.todo, 'C');
      await _settle();
      final ids = notifier.state[BoardColumnId.todo]!.map((t) => t.id).toList();

      await notifier.bulkDelete({ids[0], ids[1]});
      await _settle();

      expect(notifier.state[BoardColumnId.todo]!.map((t) => t.title), ['C']);
    });

    test('snapshotForBulkDeleteUndo captures raw task data, and restoreBulkDelete writes it straight back', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'A', labels: ['Bug']);
      await notifier.addTask(BoardColumnId.todo, 'B');
      await notifier.addTask(BoardColumnId.todo, 'C');
      await _settle();
      final ids = notifier.state[BoardColumnId.todo]!.map((t) => t.id).toList();
      final targetIds = {ids[0], ids[1]};

      final snapshot = await notifier.snapshotForBulkDeleteUndo(targetIds);
      expect(snapshot.tasks.keys.toSet(), targetIds);
      expect(snapshot.tasks[ids[0]]!['title'], 'A');
      expect(snapshot.tasks[ids[0]]!['labels'], ['Bug']);

      // Simulates the deferred-delete flow: the real delete only runs if
      // Undo was *not* tapped, so restoring never needs to run alongside
      // it in the same test — but confirm the round trip independently
      // of bulkDelete itself, since that's already covered above.
      await notifier.bulkDelete(targetIds);
      await _settle();
      expect(notifier.state[BoardColumnId.todo]!.map((t) => t.title), ['C']);

      await notifier.restoreBulkDelete(snapshot);
      await _settle();
      expect(notifier.state[BoardColumnId.todo]!.map((t) => t.title).toSet(), {'A', 'B', 'C'});
      final restoredA = notifier.state[BoardColumnId.todo]!.firstWhere((t) => t.title == 'A');
      expect(restoredA.labels, ['Bug']);
    });

    test('restoreBulkDelete attributes the restore to whoever undid it, not the original snapshot\'s author', () async {
      // FakeFirebaseFirestore doesn't enforce security rules, so this
      // can't catch a permission-denied the way live testing did — but it
      // does pin the actual bug: writing the raw snapshot verbatim would
      // silently carry Alice's uid into `updatedBy` even though Bob is the
      // one performing the restore, which the real tasks rule
      // (`updatedBy.id == request.auth.uid`) rejects outright.
      final db = FakeFirebaseFirestore();
      final asAlice = _notifier(db, current: _alice);
      await _settle();
      await asAlice.addTask(BoardColumnId.todo, 'A');
      await _settle();
      final id = asAlice.state[BoardColumnId.todo]!.first.id;

      final asBob = _notifier(db, current: _bob);
      final snapshot = await asBob.snapshotForBulkDeleteUndo({id});
      expect(snapshot.tasks[id]!['updatedBy']['id'], 'alice');

      await asBob.bulkDelete({id});
      await asBob.restoreBulkDelete(snapshot);
      await _settle();

      final doc = await db.collection('boards').doc('board-1').collection('tasks').doc(id).get();
      expect(doc.data()!['updatedBy']['id'], 'bob');
    });

    test('addComment notifies a mentioned board member by username, but not a non-member', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('usernames').doc('bobby').set({'uid': 'bob'});
      await db.collection('users').doc('bob').set({'id': 'bob', 'name': 'Bob', 'initials': 'BO', 'color': AppColors.priorityHigh.toARGB32()});
      await db.collection('usernames').doc('carol').set({'uid': 'carol'});
      await db.collection('users').doc('carol').set({'id': 'carol', 'name': 'Carol', 'initials': 'CA', 'color': AppColors.priorityHigh.toARGB32()});

      final notifier = _notifier(db, current: _alice);
      await _settle();
      // Bob is on the board (via assignee below); Carol is mentioned but
      // never appears in boardMembers, so she should not be notified.
      await notifier.addTask(BoardColumnId.todo, 'Task', assignee: _alice);
      await _settle();
      final id = notifier.state[BoardColumnId.todo]!.first.id;

      await notifier.addComment(id, 'hey @bobby and @carol, take a look', boardMembers: const [_alice, _bob]);
      await _settle();

      final bobNotifs = await db.collection('users').doc('bob').collection('notifications').get();
      final carolNotifs = await db.collection('users').doc('carol').collection('notifications').get();
      expect(bobNotifs.docs, hasLength(1));
      expect(bobNotifs.docs.first.data()['type'], 'mention');
      expect(carolNotifs.docs, isEmpty);
    });

    test('bulkImportTasks assigns a single clean name match with no warning', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db, current: _alice);
      await _settle();

      final rows = [
        const ParsedCsvTask(
          title: 'Imported for Bob',
          description: 'desc',
          column: BoardColumnId.inProgress,
          priority: Priority.high,
          labels: ['Bug'],
          assigneeName: 'Bob',
        ),
      ];

      final result = await notifier.bulkImportTasks(rows, const [_alice, _bob]);
      await _settle();

      expect(result.count, 1);
      expect(result.warnings, isEmpty);
      final inProgress = notifier.state[BoardColumnId.inProgress]!;
      expect(inProgress.map((t) => t.title), ['Imported for Bob']);
      expect(inProgress.first.assignee.id, 'bob');
      expect(inProgress.first.labels, ['Bug']);
    });

    test('bulkImportTasks leaves a blank assignee cell on the importer with no warning', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db, current: _alice);
      await _settle();

      final rows = [
        const ParsedCsvTask(
          title: 'Imported, unassigned',
          description: '',
          column: BoardColumnId.todo,
          priority: Priority.low,
          labels: [],
          assigneeName: '',
        ),
      ];

      final result = await notifier.bulkImportTasks(rows, const [_alice, _bob]);
      await _settle();

      expect(result.warnings, isEmpty);
      final todo = notifier.state[BoardColumnId.todo]!;
      expect(todo.first.assignee.id, 'alice');
    });

    test('bulkImportTasks warns and falls back to the importer for a misspelled/unmatched assignee name', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db, current: _alice);
      await _settle();

      final rows = [
        const ParsedCsvTask(
          title: 'Typo assignee',
          description: '',
          column: BoardColumnId.todo,
          priority: Priority.low,
          labels: [],
          assigneeName: 'Bobb', // misspelled — no board member matches
        ),
      ];

      final result = await notifier.bulkImportTasks(rows, const [_alice, _bob]);
      await _settle();

      expect(result.count, 1);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.taskTitle, 'Typo assignee');
      expect(result.warnings.single.message, contains('No board member named "Bobb"'));
      final todo = notifier.state[BoardColumnId.todo]!;
      expect(todo.first.assignee.id, 'alice'); // silently reassigning would be the bug
    });

    test('bulkImportTasks warns and picks the first match when two board members share a name', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db, current: _alice);
      await _settle();

      const ahmed1 = Member(id: 'ahmed1', name: 'Ahmed', initials: 'AH', color: AppColors.priorityLow);
      const ahmed2 = Member(id: 'ahmed2', name: 'Ahmed', initials: 'AH', color: AppColors.priorityMedium);

      final rows = [
        const ParsedCsvTask(
          title: 'Ambiguous assignee',
          description: '',
          column: BoardColumnId.todo,
          priority: Priority.low,
          labels: [],
          assigneeName: 'Ahmed',
        ),
      ];

      final result = await notifier.bulkImportTasks(rows, const [_alice, ahmed1, ahmed2]);
      await _settle();

      expect(result.count, 1);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.taskTitle, 'Ambiguous assignee');
      expect(result.warnings.single.message, contains('2 board members are named "Ahmed"'));
      final todo = notifier.state[BoardColumnId.todo]!;
      // Assigned to *a* match, not silently defaulted to the importer —
      // and the warning is what actually flags the ambiguity to a human.
      expect(todo.first.assignee.id, 'ahmed1');
    });

    test('addAttachment appends and removeAttachment removes by value', () async {
      final db = FakeFirebaseFirestore();
      final notifier = _notifier(db);
      await _settle();
      await notifier.addTask(BoardColumnId.todo, 'Task');
      await _settle();
      final id = notifier.state[BoardColumnId.todo]!.first.id;

      await notifier.addAttachment(id, 'base64-a');
      await notifier.addAttachment(id, 'base64-b');
      await _settle();
      expect(notifier.taskById(id)!.attachments, ['base64-a', 'base64-b']);

      await notifier.removeAttachment(id, 'base64-a');
      await _settle();
      expect(notifier.taskById(id)!.attachments, ['base64-b']);
    });
  });
}
