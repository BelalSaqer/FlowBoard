import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import '../models/task_card.dart';
import 'board_tasks_provider.dart';
import 'boards_provider.dart';
import '../screens/auth_gate.dart';

class BoardTaskRef {
  final Board board;
  final TaskCard task;
  const BoardTaskRef({required this.board, required this.task});
}

/// Every task assigned to the current user, across every board they're a
/// member of — built by watching each board's own [boardTasksProvider]
/// (the same per-board query every board screen already uses), not a
/// `collectionGroup` query. A collection-group query here would hit the
/// exact class of bug that once broke the boards list itself: Firestore
/// rejects a list query outright when its security rule depends on
/// per-document fields the query can't prove hold for every result, and
/// the `tasks` rule depends on `get()`-ing the parent board. Combining
/// already-safe per-board streams client-side sidesteps that entirely, at
/// the cost of one live listener per board while this is being watched —
/// a fine trade for the handful of boards a typical member is on.
final myTasksProvider = Provider.autoDispose<List<BoardTaskRef>>((ref) {
  final boards = ref.watch(boardsProvider);
  final myId = ref.watch(currentMemberStateProvider)?.id;
  if (myId == null) return const [];

  final refs = <BoardTaskRef>[];
  for (final board in boards) {
    final tasksByColumn = ref.watch(boardTasksProvider(board.id));
    for (final tasks in tasksByColumn.values) {
      for (final task in tasks) {
        if (task.assignee.id == myId) refs.add(BoardTaskRef(board: board, task: task));
      }
    }
  }

  int rank(TaskCard t) {
    if (t.isOverdue) return 0;
    if (t.isDueSoon) return 1;
    if (t.dueDate != null) return 2;
    return 3;
  }

  refs.sort((a, b) {
    final byRank = rank(a.task).compareTo(rank(b.task));
    if (byRank != 0) return byRank;
    final aDue = a.task.dueDate;
    final bDue = b.task.dueDate;
    if (aDue != null && bDue != null) return aDue.compareTo(bDue);
    return 0;
  });
  return refs;
});
