import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firestore_mappers.dart';
import '../models/member.dart';
import '../models/notification_entry.dart';
import '../screens/auth_gate.dart';
import 'profile_provider.dart';

CollectionReference<Map<String, dynamic>> _notificationsCol(FirebaseFirestore db, String uid) =>
    db.collection('users').doc(uid).collection('notifications');

NotificationEntry _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;
  return NotificationEntry(
    id: doc.id,
    type: NotificationType.values.firstWhere((t) => t.name == data['type']),
    actor: memberFromMap(Map<String, dynamic>.from(data['actor'] as Map)),
    taskTitle: data['taskTitle'] as String,
    boardId: data['boardId'] as String,
    taskId: data['taskId'] as String,
    read: data['read'] as bool? ?? false,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

/// Writes a notification into [recipient]'s subtree. Skips self-notify
/// (e.g. assigning a task to yourself, or commenting on your own task).
Future<void> writeNotification(
  FirebaseFirestore db, {
  required Member recipient,
  required Member actor,
  required NotificationType type,
  required String boardId,
  required String taskId,
  required String taskTitle,
}) async {
  if (recipient.id == actor.id) return;
  await _notificationsCol(db, recipient.id).add({
    'type': type.name,
    'actor': memberToMap(actor),
    'boardId': boardId,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

final notificationsProvider = StreamProvider.autoDispose<List<NotificationEntry>>((ref) {
  final me = ref.watch(currentMemberStateProvider);
  final db = ref.watch(firestoreProvider);
  if (me == null) return const Stream.empty();
  return _notificationsCol(db, me.id)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) _fromDoc(d)]);
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifs = ref.watch(notificationsProvider).value ?? const [];
  return notifs.where((n) => !n.read).length;
});

Future<void> markAllNotificationsRead(FirebaseFirestore db, String uid, List<NotificationEntry> unread) async {
  if (unread.isEmpty) return;
  final batch = db.batch();
  for (final n in unread) {
    batch.update(_notificationsCol(db, uid).doc(n.id), {'read': true});
  }
  await batch.commit();
}

Future<void> markNotificationRead(FirebaseFirestore db, String uid, String notifId) async {
  await _notificationsCol(db, uid).doc(notifId).update({'read': true});
}
