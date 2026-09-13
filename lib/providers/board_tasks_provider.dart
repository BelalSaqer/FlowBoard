import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/csv_export.dart';
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
import '../services/deep_link.dart';
import '../services/gemini_service.dart' as gemini;
import '../theme/app_colors.dart';
import 'profile_provider.dart';
import '../screens/auth_gate.dart';

typedef BoardTasksState = Map<BoardColumnId, List<TaskCard>>;

BoardTasksState _emptyState() => {for (final c in BoardColumnId.values) c: <TaskCard>[]};

/// One row of a CSV import whose assignee couldn't be resolved cleanly —
/// either no board member matched the name, or more than one did. See
/// [BoardTasksNotifier._resolveImportAssignee].
class ImportWarning {
  final String taskTitle;
  final String message;
  const ImportWarning({required this.taskTitle, required this.message});
}

class BulkImportResult {
  final int count;
  final List<ImportWarning> warnings;
  const BulkImportResult({required this.count, required this.warnings});
}

/// Raw Firestore data for a set of tasks, captured just before a bulk
/// delete so it can be undone — mirrors [BoardDeleteSnapshot] in
/// boards_provider.dart.
class BulkTaskDeleteSnapshot {
  final Map<String, Map<String, dynamic>> tasks;
  const BulkTaskDeleteSnapshot({required this.tasks});
}

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
    _sub = _tasksCol.orderBy('order').snapshots().listen(_onSnapshot, onError: _onSnapshotError);
  }

  // A silently-dropped listener here means the board a user is actively
  // looking at just stops updating with no indication why (permission
  // changes after a rules deploy, a network drop, etc.) — at minimum this
  // needs to be visible in logs, and since this is the main data on
  // screen, a transient banner via the same app-level ScaffoldMessenger
  // the undo snackbars already use.
  void _onSnapshotError(Object error) {
    debugPrint('BoardTasksNotifier: tasks listener error for board $boardId: $error');
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text("Lost the live connection to this board's tasks.")),
    );
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

  // Known limitation: repeatedly inserting between the same two neighbors
  // (e.g. always dropping a card into the same gap) halves the remaining
  // gap each time via (a+b)/2, so double-precision limits mean enough
  // repeated insertions at that exact position will eventually produce a
  // collision (two tasks with an identical `order`) — they'd sort
  // arbitrarily relative to each other until one of them moves again. In
  // practice this needs dozens of insertions at the *exact* same spot
  // without ever touching the rest of the column, which real usage
  // doesn't hit, so it's left undefended for now rather than adding
  // periodic rebalancing (recomputing clean integer-spaced orders for a
  // column) — that would need to safely batch-rewrite every sibling
  // under concurrent drags from other viewers, which is real scope, not
  // a small fix.
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

  // Negative lookbehind stops this from firing inside a plain email
  // address ("ahmed@company.com" would otherwise parse "@company" as a
  // mention) — the @ can't be immediately preceded by a letter or digit.
  static final _mentionPattern = RegExp(r'(?<![a-zA-Z0-9])@([a-z0-9_]{3,20})', caseSensitive: false);

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

  static const maxAttachments = 3;

  Future<void> addAttachment(String taskId, String base64Image) async {
    final me = currentMember();
    await _tasksCol.doc(taskId).update({
      'attachments': FieldValue.arrayUnion([base64Image]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': memberToMap(me),
    });
  }

  Future<void> removeAttachment(String taskId, String base64Image) async {
    final me = currentMember();
    await _tasksCol.doc(taskId).update({
      'attachments': FieldValue.arrayRemove([base64Image]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': memberToMap(me),
    });
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

  /// Captures every selected task's raw data, so a bulk delete can be
  /// undone within the confirmation snackbar's window (see
  /// [BoardDetailScreen]) by writing them straight back — the same
  /// snapshot-before-delete pattern [BoardsNotifier.snapshotForUndo] uses
  /// for whole-board deletion.
  Future<BulkTaskDeleteSnapshot> snapshotForBulkDeleteUndo(Set<String> taskIds) async {
    final tasks = <String, Map<String, dynamic>>{};
    for (final id in taskIds) {
      final snap = await _tasksCol.doc(id).get();
      final data = snap.data();
      if (data != null) tasks[id] = data;
    }
    return BulkTaskDeleteSnapshot(tasks: tasks);
  }

  /// Writes each snapshotted task straight back — but stamped with the
  /// *current* user as `updatedBy`/`updatedAt`, not the original snapshot's
  /// values. Writing the raw snapshot verbatim would carry whoever last
  /// touched that task before the delete (almost never the person tapping
  /// Undo) into `updatedBy`, which fails the tasks rule's identity check
  /// (`request.resource.data.updatedBy.id == request.auth.uid`) with a
  /// permission-denied — caught by actually tapping Undo against the live
  /// rules rather than trusting the round trip in isolation. Attributing
  /// the restore to whoever undid it is also just the honest answer: they
  /// really are the one who caused this write.
  Future<void> restoreBulkDelete(BulkTaskDeleteSnapshot snapshot) async {
    final me = currentMember();
    final batch = db.batch();
    for (final entry in snapshot.tasks.entries) {
      final data = Map<String, dynamic>.from(entry.value);
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['updatedBy'] = memberToMap(me);
      batch.set(_tasksCol.doc(entry.key), data);
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

  /// Resolves one CSV row's "Assignee" cell against [boardMembers] by
  /// exact case-insensitive name match. A blank cell is a deliberate
  /// "no assignee specified" and falls back to [importer] silently, same
  /// as leaving assignee unset in the New Task sheet — but a non-blank
  /// name that doesn't resolve to exactly one member is a real ambiguity
  /// a human should see, not something to paper over:
  ///  - zero matches (typo, or someone not on this board) falls back to
  ///    [importer] and returns a warning saying so;
  ///  - more than one match (two members with the same display name —
  ///    common enough with names like "Ahmed") assigns the first match
  ///    and returns a warning naming the ambiguity, rather than silently
  ///    picking one with no indication anything was uncertain.
  (Member, String?) _resolveImportAssignee(String assigneeName, List<Member> boardMembers, Member importer) {
    if (assigneeName.isEmpty) return (importer, null);
    final matches = boardMembers.where((m) => m.name.toLowerCase() == assigneeName.toLowerCase()).toList();
    if (matches.length == 1) return (matches.first, null);
    if (matches.isEmpty) {
      return (importer, 'No board member named "$assigneeName" — assigned to you instead.');
    }
    return (
      matches.first,
      '${matches.length} board members are named "$assigneeName" — assigned to the first one; double-check this is the right person.',
    );
  }

  /// Creates one task per parsed CSV row, appended to the end of its
  /// target column. See [_resolveImportAssignee] for how the "Assignee"
  /// column is matched and when that produces a warning instead of a
  /// silent fallback.
  Future<BulkImportResult> bulkImportTasks(List<ParsedCsvTask> rows, List<Member> boardMembers) async {
    final me = currentMember();
    final columnEnds = <BoardColumnId, double>{
      for (final c in BoardColumnId.values)
        c: state[c]!.isEmpty ? 0.0 : _docsById[state[c]!.last.id]!.order,
    };
    final batch = db.batch();
    final warnings = <ImportWarning>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final (assignee, warning) = _resolveImportAssignee(row.assigneeName, boardMembers, me);
      if (warning != null) {
        warnings.add(ImportWarning(taskTitle: row.title, message: warning));
      }
      columnEnds[row.column] = columnEnds[row.column]! + 1000.0;
      final activity = ActivityEntry(
        id: 'a-${DateTime.now().microsecondsSinceEpoch}-$i',
        text: '${me.name} imported this card',
        time: DateTime.now(),
        dotColor: AppColors.primary,
      );
      batch.set(_tasksCol.doc(), {
        'title': row.title,
        'description': row.description,
        'priority': row.priority.name,
        'assignee': memberToMap(assignee),
        'dueDate': null,
        'column': row.column.name,
        'order': columnEnds[row.column],
        'subtasks': <Map<String, dynamic>>[],
        'comments': <Map<String, dynamic>>[],
        'activity': [activityToMap(activity)],
        'labels': row.labels,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': memberToMap(me),
      });
    }
    await batch.commit();
    return BulkImportResult(count: rows.length, warnings: warnings);
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
