import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/data/board_templates.dart';
import 'package:flowboard/models/board_column.dart';
import 'package:flowboard/models/member.dart';
import 'package:flowboard/providers/boards_provider.dart';
import 'package:flowboard/theme/app_colors.dart';

const _alice = Member(id: 'alice', name: 'Alice', initials: 'AL', color: AppColors.primary);
const _bob = Member(id: 'bob', name: 'Bob', initials: 'BO', color: AppColors.priorityHigh);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('BoardsNotifier', () {
    test('createBoard seeds memberIds and an owner role for the creator', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();

      await notifier.createBoard('Roadmap', Colors.blue, _alice);
      await _settle();

      final snap = await db.collection('boards').where('name', isEqualTo: 'Roadmap').get();
      final data = snap.docs.single.data();
      expect(data['memberIds'], ['alice']);
      expect(data['ownerId'], 'alice');
      expect(data['roles'], {'alice': 'owner'});
    });

    test('addMember appends to memberIds and defaults the new member to editor', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();
      await notifier.createBoard('Roadmap', Colors.blue, _alice);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Roadmap').get()).docs.single.id;

      await notifier.addMember(boardId, _bob);
      await _settle();

      final data = (await db.collection('boards').doc(boardId).get()).data()!;
      expect(data['memberIds'], containsAll(['alice', 'bob']));
      expect(data['roles'], {'alice': 'owner', 'bob': 'editor'});
    });

    test('setMemberRole updates only the target uid in the roles map', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();
      await notifier.createBoard('Roadmap', Colors.blue, _alice);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Roadmap').get()).docs.single.id;
      await notifier.addMember(boardId, _bob);
      await _settle();

      await notifier.setMemberRole(boardId, 'bob', 'viewer');
      await _settle();

      final data = (await db.collection('boards').doc(boardId).get()).data()!;
      expect(data['roles'], {'alice': 'owner', 'bob': 'viewer'});
    });

    test('archiveBoard then unarchiveBoard round-trips through fetchArchivedBoards', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();
      await notifier.createBoard('Roadmap', Colors.blue, _alice);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Roadmap').get()).docs.single.id;

      await notifier.archiveBoard(boardId);
      await _settle();
      expect(notifier.state.any((b) => b.id == boardId), isFalse);

      final archived = await notifier.fetchArchivedBoards('alice');
      expect(archived.map((b) => b.id), contains(boardId));

      await notifier.unarchiveBoard(boardId);
      await _settle();
      expect(notifier.state.any((b) => b.id == boardId), isTrue);
    });

    test('joinBoardByLink adds the joiner as editor once the link is enabled', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();
      await notifier.createBoard('Roadmap', Colors.blue, _alice);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Roadmap').get()).docs.single.id;

      await notifier.setLinkJoinEnabled(boardId, true);
      await _settle();

      final joined = await notifier.joinBoardByLink(boardId, _bob);
      expect(joined.roleOf('bob'), 'editor');

      final data = (await db.collection('boards').doc(boardId).get()).data()!;
      expect(data['memberIds'], containsAll(['alice', 'bob']));
      expect(data['roles']['bob'], 'editor');
    });

    test('joinBoardByLink throws if the link has been turned off', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();
      await notifier.createBoard('Roadmap', Colors.blue, _alice);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Roadmap').get()).docs.single.id;

      expect(() => notifier.joinBoardByLink(boardId, _bob), throwsStateError);
    });

    test('joinBoardByLink is a no-op if already a member', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();
      await notifier.createBoard('Roadmap', Colors.blue, _alice);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Roadmap').get()).docs.single.id;

      final joined = await notifier.joinBoardByLink(boardId, _alice);
      expect(joined.roleOf('alice'), 'owner');
    });

    test('createBoard with a template seeds its starter tasks into the right columns', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();

      final template = boardTemplates.firstWhere((t) => t.name == 'Bug tracker');
      await notifier.createBoard('Bugs', Colors.red, _alice, templateTasks: template.tasks);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Bugs').get()).docs.single.id;

      final tasks = await db.collection('boards').doc(boardId).collection('tasks').get();
      expect(tasks.docs, hasLength(template.tasks.length));
      final titles = tasks.docs.map((d) => d.data()['title'] as String).toSet();
      expect(titles, template.tasks.map((t) => t.title).toSet());
      for (final doc in tasks.docs) {
        expect(doc.data()['assignee']['id'], 'alice');
        expect(doc.data()['updatedBy']['id'], 'alice');
      }

      final doneCount = tasks.docs.where((d) => d.data()['column'] == BoardColumnId.done.name).length;
      expect(doneCount, template.tasks.where((t) => t.column == BoardColumnId.done).length);
    });

    test('createBoard with the Blank template seeds no tasks', () async {
      final db = FakeFirebaseFirestore();
      final notifier = BoardsNotifier(db, 'alice', false);
      await _settle();

      await notifier.createBoard('Empty', Colors.grey, _alice, templateTasks: boardTemplates.first.tasks);
      await _settle();
      final boardId = (await db.collection('boards').where('name', isEqualTo: 'Empty').get()).docs.single.id;

      final tasks = await db.collection('boards').doc(boardId).collection('tasks').get();
      expect(tasks.docs, isEmpty);
    });
  });
}
