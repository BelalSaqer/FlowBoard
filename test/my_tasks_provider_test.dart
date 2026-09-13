import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/models/board_column.dart';
import 'package:flowboard/models/member.dart';
import 'package:flowboard/providers/auth_provider.dart';
import 'package:flowboard/providers/board_tasks_provider.dart';
import 'package:flowboard/providers/boards_provider.dart';
import 'package:flowboard/providers/my_tasks_provider.dart';
import 'package:flowboard/providers/profile_provider.dart';
import 'package:flowboard/screens/auth_gate.dart';
import 'package:flowboard/theme/app_colors.dart';

const _alice = Member(id: 'alice', name: 'Alice', initials: 'AL', color: AppColors.primary);
const _bob = Member(id: 'bob', name: 'Bob', initials: 'BO', color: AppColors.priorityHigh);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('myTasksProvider combines tasks assigned to the current user across every board they belong to', () async {
    final db = FakeFirebaseFirestore();
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice', isAnonymous: false)),
      ),
      currentMemberStateProvider.overrideWith((ref) => _alice),
    ]);
    addTearDown(container.dispose);

    // Keep the autoDispose chain alive across the awaits below.
    container.listen(myTasksProvider, (_, _) {});

    await container.read(boardsProvider.notifier).createBoard('Board A', AppColors.primary, _alice);
    await _settle();
    final boardAId = (await db.collection('boards').where('name', isEqualTo: 'Board A').get()).docs.single.id;

    await container.read(boardsProvider.notifier).createBoard('Board B', AppColors.primary, _alice);
    await _settle();
    final boardBId = (await db.collection('boards').where('name', isEqualTo: 'Board B').get()).docs.single.id;

    final tasksA = container.read(boardTasksProvider(boardAId).notifier);
    await tasksA.addTask(BoardColumnId.todo, 'For Alice on A', assignee: _alice);
    await tasksA.addTask(BoardColumnId.todo, 'For Bob on A', assignee: _bob);
    await _settle();

    final tasksB = container.read(boardTasksProvider(boardBId).notifier);
    await tasksB.addTask(BoardColumnId.inProgress, 'For Alice on B', assignee: _alice);
    await _settle();

    final refs = container.read(myTasksProvider);
    expect(refs.map((r) => r.task.title).toSet(), {'For Alice on A', 'For Alice on B'});
    expect(refs.every((r) => r.task.assignee.id == 'alice'), isTrue);
    expect(refs.map((r) => r.board.name).toSet(), {'Board A', 'Board B'});
  });

  test('myTasksProvider sorts overdue before due-soon before everything else', () async {
    final db = FakeFirebaseFirestore();
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(
        MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice', isAnonymous: false)),
      ),
      currentMemberStateProvider.overrideWith((ref) => _alice),
    ]);
    addTearDown(container.dispose);
    container.listen(myTasksProvider, (_, _) {});

    await container.read(boardsProvider.notifier).createBoard('Board A', AppColors.primary, _alice);
    await _settle();
    final boardId = (await db.collection('boards').where('name', isEqualTo: 'Board A').get()).docs.single.id;
    final tasks = container.read(boardTasksProvider(boardId).notifier);

    await tasks.addTask(BoardColumnId.todo, 'No due date', assignee: _alice);
    await tasks.addTask(BoardColumnId.todo, 'Overdue', assignee: _alice, dueDate: DateTime.now().subtract(const Duration(days: 2)));
    await tasks.addTask(BoardColumnId.todo, 'Due soon', assignee: _alice, dueDate: DateTime.now().add(const Duration(hours: 12)));
    await _settle();

    final refs = container.read(myTasksProvider);
    expect(refs.map((r) => r.task.title), ['Overdue', 'Due soon', 'No due date']);
  });
}
