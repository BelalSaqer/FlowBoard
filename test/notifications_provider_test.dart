import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/models/member.dart';
import 'package:flowboard/providers/notifications_provider.dart';
import 'package:flowboard/providers/profile_provider.dart';
import 'package:flowboard/screens/auth_gate.dart';
import 'package:flowboard/theme/app_colors.dart';

const _alice = Member(id: 'alice', name: 'Alice', initials: 'AL', color: AppColors.primary);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('unreadNotificationCountProvider counts every unread notification, not just the page size loaded elsewhere', () async {
    final db = FakeFirebaseFirestore();

    // notificationsPageSizeProvider defaults to 20 — seed more unread
    // notifications than that to prove the count isn't derived from (and
    // therefore capped by) that paginated list.
    for (var i = 0; i < 25; i++) {
      await db.collection('users').doc('alice').collection('notifications').add({
        'type': 'comment',
        'actor': {'id': 'bob', 'name': 'Bob', 'initials': 'BO', 'color': AppColors.priorityHigh.toARGB32()},
        'boardId': 'board-1',
        'taskId': 'task-$i',
        'taskTitle': 'Task $i',
        'read': false,
        'createdAt': DateTime.now(),
      });
    }
    // A handful of already-read notifications shouldn't count.
    for (var i = 0; i < 5; i++) {
      await db.collection('users').doc('alice').collection('notifications').add({
        'type': 'comment',
        'actor': {'id': 'bob', 'name': 'Bob', 'initials': 'BO', 'color': AppColors.priorityHigh.toARGB32()},
        'boardId': 'board-1',
        'taskId': 'read-task-$i',
        'taskTitle': 'Read task $i',
        'read': true,
        'createdAt': DateTime.now(),
      });
    }

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      currentMemberStateProvider.overrideWith((ref) => _alice),
    ]);
    addTearDown(container.dispose);
    container.listen(unreadNotificationCountProvider, (_, _) {});
    await _settle();

    final count = container.read(unreadNotificationCountProvider).value;
    expect(count, 25);
  });
}
