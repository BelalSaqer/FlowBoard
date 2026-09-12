import 'package:cloud_firestore/cloud_firestore.dart';
import 'mock_data.dart';
import 'firestore_mappers.dart';

/// One-time seed of the demo boards/tasks into Firestore, guarded by a
/// transaction on `meta/seed` so concurrent app launches (e.g. two
/// browser tabs opening at once) can't double-seed.
Future<void> seedIfNeeded(FirebaseFirestore db) async {
  final seedMarker = db.collection('meta').doc('seed');

  final didSeed = await db.runTransaction<bool>((txn) async {
    final marker = await txn.get(seedMarker);
    if (marker.exists) return false;

    txn.set(seedMarker, {'seededAt': FieldValue.serverTimestamp()});

    for (final board in MockData.boards) {
      final boardRef = db.collection('boards').doc(board.id);
      txn.set(boardRef, boardToMap(board));

      final tasksByColumn = MockData.tasksForBoard(board.id);
      for (final tasks in tasksByColumn.values) {
        for (var i = 0; i < tasks.length; i++) {
          final taskRef = boardRef.collection('tasks').doc(tasks[i].id);
          txn.set(taskRef, taskToSeedMap(tasks[i], i * 1000.0));
        }
      }
    }
    return true;
  });

  if (didSeed) {
    // ignore: avoid_print
    print('Seeded demo boards into Firestore.');
  }
}
