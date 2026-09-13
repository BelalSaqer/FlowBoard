import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firestore_mappers.dart';
import '../models/activity_entry.dart';
import '../models/board_column.dart';
import '../models/comment.dart';
import '../models/member.dart';
import '../models/priority.dart';
import '../models/subtask.dart';
import '../models/notification_entry.dart';
import '../models/task_card.dart';
import '../providers/notifications_provider.dart';
import '../services/gemini_service.dart' as gemini;
import '../theme/app_colors.dart';
import 'profile_provider.dart';
import '../screens/auth_gate.dart';

typedef BoardTasksState = Map<BoardColumnId, List<TaskCard>>;

BoardTasksState _emptyState() => {for (final c in BoardColumnId.values) c: <TaskCard>[]};

/// Holds the task cards for one board, grouped by column, streamed live
/// from `boards/{boardId}/tasks`. Every mutation writes to Firestore and
/// the resulting state update flows back through the same snapshot
/// listener every open tab/device shares — that round trip *is* the
/// real-time sync, not an optimistic local patch.
class BoardTasksNotifier extends StateNotifier<BoardTasksState> {
  final FirebaseFirestore db;
  final String boardId;
  final Member Function() currentMember;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Map<String, TaskDoc> _docsById = {};

  BoardTasksNotifier(this.db, this.boardId, this.currentMember) : super(_emptyState()) {
    _sub = _tasksCol.orderBy('order').snapshots().listen(_onSnapshot, onError: (_) {});
  }

  CollectionReference<Map<String, dynamic>> get _tasksCol =>
      db.collection('boards').doc(boardId).collection('tasks');

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    final docsById = <String, TaskDoc>{};
    final grouped = _emptyState();
    for (final d in snap.docs) {
      final doc = taskDocFromDoc(d);
      docsById[d.id] = doc;
      grouped[doc.task.column]!.add(doc.task);
    }
    _docsById = docsById;
    state = grouped;
  }

  TaskCard? taskById(String taskId) => _docsById[taskId]?.task;
  TaskDoc? taskDocById(String taskId) => _docsById[taskId];

  /// Moves [taskId] into [toColumn] at [toIndex], handling both
  /// cross-column moves and same-column reordering via a fractional
  /// index — only the moved document is written, siblings are untouched.
  Future<void> moveTask({
    required String taskId,
    required BoardColumnId toColumn,
    required int toIndex,
  }) async {
    final siblings = state[toColumn]!.where((t) => t.id != taskId).toList();
    final order = _orderForIndex(siblings, toIndex);
    final me = currentMember();
    final fromColumn = taskById(taskId)?.column;
    final update = <String, dynamic>{
      'column': toColumn.name,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': memberToMap(me),
    };
    if (fromColumn != null && fromColumn != toColumn) {
      final activity = ActivityEntry(
        id: 'a-${DateTime.now().microsecondsSinceEpoch}',
        text: '${me.name} moved this card to ${toColumn.label}',
        time: DateTime.now(),
        dotColor: AppColors.primary,
      );
      update['activity'] = FieldValue.arrayUnion([activityToMap(activity)]);
    }
    await _tasksCol.doc(taskId).update(update);
  }

  double _orderForIndex(List<TaskCard> siblingsExcludingSelf, int index) {
    final orders = [for (final t in siblingsExcludingSelf) _docsById[t.id]!.order];
    if (orders.isEmpty) return 1000.0;
    final clamped = index.clamp(0, orders.length);
    if (clamped == 0) return orders.first - 1000.0;
    if (clamped == orders.length) return orders.last + 1000.0;
    return (orders[clamped - 1] + orders[clamped]) / 2;
  }

  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final me = currentMember();
    await db.runTransaction((txn) async {
      final ref = _tasksCol.doc(taskId);
      final snap = await txn.get(ref);
      final data = snap.data();
      if (data == null) return;
      final subtasks = [
        for (final s in (data['subtasks'] as List<dynamic>? ?? []))
          Map<String, dynamic>.from(s as Map),
      ];
      for (final s in subtasks) {
        if (s['id'] == subtaskId) s['done'] = !(s['done'] as bool? ?? false);
      }
      txn.update(ref, {
        'subtasks': subtasks,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': memberToMap(me),
      });
    });
  }

  static final _mentionPattern = RegExp(r'@([a-z0-9_]{3,20})', caseSensitive: false);

  Future<void> addComment(String taskId, String body, {List<Member> boardMembers = const []}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final me = currentMember();
    final comment = TaskComment(
      id: 'c-${DateTime.now().microsecondsSinceEpoch}',
      author: me,
      time: DateTime.now(),
      body: trimmed,
    );
    final activity = ActivityEntry(
      id: 'a-${DateTime.now().microsecondsSinceEpoch}',
      text: '${me.name} commented on this card',
      time: DateTime.now(),
      dotColor: AppColors.priorityLow,
    );
    await _tasksCol.doc(taskId).update({
      'comments': FieldValue.arrayUnion([commentToMap(comment)]),
      'activity': FieldValue.arrayUnion([activityToMap(activity)]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': memberToMap(me),
    });

    final task = taskById(taskId);
    if (task != null) {
      await writeNotification(
        db,
        recipient: task.assignee,
        actor: me,
        type: NotificationType.comment,
        boardId: boardId,
        taskId: taskId,
        taskTitle: task.title,
      );

      // @mentions: each token is a reserved username, resolved via the
      // same `usernames` lookup invites use — then restricted to this
      // board's own members, since mentioning someone who can't even see
      // the task wouldn't mean anything.
      final handles = <String>{
        for (final match in _mentionPattern.allMatches(trimmed)) match.group(1)!.toLowerCase(),
      };
      final memberIds = boardMembers.map((m) => m.id).toSet();
      for (final handle in handles) {
        final mentioned = await findMemberByUsername(db, handle);
        if (mentioned == null) continue;
        if (mentioned.id == me.id || !memberIds.contains(mentioned.id)) continue;
        if (mentioned.id == task.assignee.id) continue; // already notified above
        await writeNotification(
          db,
          recipient: mentioned,
          actor: me,
          type: NotificationType.mention,
          boardId: boardId,
          taskId: taskId,
          taskTitle: task.title,
        );
      }
    }
  }

  Future<void> setLabels(String taskId, List<String> labels) async {
    final me = currentMember();
    await _tasksCol.doc(taskId).update({
      'labels': labels,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': memberToMap(me),
    });
  }

  /// Moves every task in [taskIds] into [toColumn], appended after that
  /// column's current last card. One batch write, so a bulk move of many
  /// cards is still a single round trip.
  Future<void> bulkMove(Set<String> taskIds, BoardColumnId toColumn) async {
    final me = currentMember();
    final batch = db.batch();
    final existing = state[toColumn]!;
    var order = existing.isEmpty ? 0.0 : _docsById[existing.last.id]!.order;
    for (final id in taskIds) {
      order += 1000.0;
      batch.update(_tasksCol.doc(id), {
        'column': toColumn.name,
        'order': order,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': memberToMap(me),
      });
    }
    await batch.commit();
  }

  Future<void> bulkDelete(Set<String> taskIds) async {
    final batch = db.batch();
    for (final id in taskIds) {
      batch.delete(_tasksCol.doc(id));
    }
    await batch.commit();
  }

  static const _fallbackSuggestions = [
    'Define the presence payload schema',
    'Interpolate cursor positions client-side',
    'Fade viewers idle for 30s',
    'Reorder header avatars by activity',
  ];

  /// AI task-breakdown (stretch feature). Calls Gemini when an API key is
  /// configured (`--dart-define=GEMINI_API_KEY=...`); otherwise falls back
  /// to a static suggestion list so the feature still demos without one.
  Future<void> generateAiSubtasks(String taskId) async {
    final task = taskById(taskId);
    List<String> suggestions;
    if (gemini.geminiConfigured && task != null) {
      try {
        suggestions = await gemini.suggestSubtasks(
          title: task.title,
          description: task.description,
        );
      } catch (_) {
        suggestions = _fallbackSuggestions;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 900));
      suggestions = _fallbackSuggestions;
    }

    final me = currentMember();
    await db.runTransaction((txn) async {
      final ref = _tasksCol.doc(taskId);
      final snap = await txn.get(ref);
      final data = snap.data();
      if (data == null) return;
      final existing = data['subtasks'] as List<dynamic>? ?? [];
      if (existing.isNotEmpty) return;
      final subtasks = [
        for (var i = 0; i < suggestions.length; i++)
          subtaskToMap(SubTask(id: 's-$taskId-$i', text: suggestions[i], done: i == 0)),
      ];
      txn.update(ref, {
        'subtasks': subtasks,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': memberToMap(me),
      });
    });
  }

  Future<void> addTask(
    BoardColumnId column,
    String title, {
    String description = '',
    Priority priority = Priority.medium,
    Member? assignee,
    DateTime? dueDate,
    List<String> labels = const [],
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final me = currentMember();
    final existing = state[column]!;
    final order = existing.isEmpty ? 0.0 : _docsById[existing.last.id]!.order + 1000.0;
    final activity = ActivityEntry(
      id: 'a-${DateTime.now().microsecondsSinceEpoch}',
      text: '${me.name} created this card',
      time: DateTime.now(),
      dotColor: AppColors.primary,
    );
    final finalAssignee = assignee ?? me;
    final ref = await _tasksCol.add({
      'title': trimmed,
      'description': description.trim(),
      'priority': priority.name,
      'assignee': memberToMap(finalAssignee),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'column': column.name,
      'order': order,
      'subtasks': <Map<String, dynamic>>[],
      'comments': <Map<String, dynamic>>[],
      'activity': [activityToMap(activity)],
      'labels': labels,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': memberToMap(me),
    });

    await writeNotification(
      db,
      recipient: finalAssignee,
      actor: me,
      type: NotificationType.assigned,
      boardId: boardId,
      taskId: ref.id,
      taskTitle: trimmed,
    );
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksCol.doc(taskId).delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final boardTasksProvider = StateNotifierProvider.autoDispose.family<BoardTasksNotifier, BoardTasksState, String>((
  ref,
  boardId,
) {
  final me = ref.watch(currentMemberStateProvider);
  return BoardTasksNotifier(
    ref.watch(firestoreProvider),
    boardId,
    () => me ?? const Member(id: '_', name: 'You', initials: 'YOU', color: AppColors.primary),
  );
});
