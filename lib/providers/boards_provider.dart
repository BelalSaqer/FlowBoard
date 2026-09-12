import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firestore_mappers.dart';
import '../data/firestore_seed.dart';
import '../models/board.dart';
import '../models/member.dart';
import 'profile_provider.dart';

class BoardsNotifier extends StateNotifier<List<Board>> {
  final FirebaseFirestore db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  BoardsNotifier(this.db) : super([]) {
    seedIfNeeded(db);
    _sub = db
        .collection('boards')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
            state = [
              for (final doc in snap.docs)
                if (doc.data()['archived'] != true) boardFromDoc(doc),
            ];
            _backfillMembership(snap.docs);
          },
          // Swallows the brief permission-denied burst that can happen if
          // this outlives sign-out by a tick before autoDispose tears it down.
          onError: (_) {},
        );
  }

  /// The original 4 boards seeded before `isDemo` existed. Kept as a
  /// fixed list (rather than inferred) so this migration can't
  /// accidentally mark a real user-created board as a public demo board.
  static const _legacySeedBoardIds = {'b1', 'b2', 'b3', 'b4'};

  /// Self-healing migration for boards written before membership-gated
  /// security rules existed: patches in `memberIds` (rules read this to
  /// decide who can access a board) and, for the original seed boards,
  /// `isDemo` (so they stay open to any visitor). A no-op once every
  /// board has been touched once.
  void _backfillMembership(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    for (final doc in docs) {
      final data = doc.data();
      final needsMemberIds = !data.containsKey('memberIds');
      final needsDemoFlag = _legacySeedBoardIds.contains(doc.id) && !data.containsKey('isDemo');
      if (!needsMemberIds && !needsDemoFlag) continue;
      final members = data['members'] as List<dynamic>? ?? [];
      final memberIds = [for (final m in members) (m as Map)['id'] as String];
      doc.reference.update({
        if (needsMemberIds) 'memberIds': memberIds,
        if (needsMemberIds && !data.containsKey('roles')) 'roles': <String, String>{},
        if (needsDemoFlag) 'isDemo': true,
      }).catchError((_) {});
    }
  }

  Future<void> createBoard(String name, Color color, Member creator) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await db.collection('boards').add(
      boardToMap(
        Board(
          id: '',
          name: trimmed,
          color: color,
          members: [creator],
          updatedAt: DateTime.now(),
          ownerId: creator.id,
          roles: {creator.id: 'owner'},
        ),
      ),
    );
  }

  Future<void> renameBoard(String boardId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await db.collection('boards').doc(boardId).update({
      'name': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recolorBoard(String boardId, Color color) async {
    await db.collection('boards').doc(boardId).update({
      'color': color.toARGB32(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveBoard(String boardId) async {
    await db.collection('boards').doc(boardId).update({'archived': true});
  }

  Future<void> unarchiveBoard(String boardId) async {
    await db.collection('boards').doc(boardId).update({'archived': false});
  }

  /// Boards the current user belongs to that have been archived, for the
  /// restore screen. One-shot rather than streamed since it's a rarely
  /// visited recovery list, not a live view.
  Future<List<Board>> fetchArchivedBoards(String uid) async {
    final snap = await db
        .collection('boards')
        .where('memberIds', arrayContains: uid)
        .where('archived', isEqualTo: true)
        .get();
    return [for (final doc in snap.docs) boardFromDoc(doc)];
  }

  Future<void> addMember(String boardId, Member member) async {
    await db.collection('boards').doc(boardId).update({
      'members': FieldValue.arrayUnion([memberToMap(member)]),
      'memberIds': FieldValue.arrayUnion([member.id]),
      'roles.${member.id}': 'editor',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Owner-only: promotes/demotes a member between 'editor' and 'viewer'.
  /// Enforced both here (UI only exposes this to the owner) and by
  /// security rules (only the owner may change the `roles` map).
  Future<void> setMemberRole(String boardId, String uid, String role) async {
    await db.collection('boards').doc(boardId).update({
      'roles.$uid': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently deletes a board along with its tasks. Firestore doesn't
  /// cascade-delete subcollections, so tasks are fetched and removed
  /// explicitly first. Presence docs are left alone — security rules
  /// restrict deleting them to their own owner, and once the board doc is
  /// gone they're unreachable anyway, so they just harmlessly age out.
  Future<void> deleteBoard(String boardId) async {
    final boardRef = db.collection('boards').doc(boardId);
    final tasks = await boardRef.collection('tasks').get();
    final batch = db.batch();
    for (final d in tasks.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    await boardRef.delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final boardsProvider = StateNotifierProvider.autoDispose<BoardsNotifier, List<Board>>((ref) {
  return BoardsNotifier(ref.watch(firestoreProvider));
});

/// Live viewers of a board, derived from heartbeat documents written by
/// [PresenceHeartbeat]. Re-filters on a timer (not just on snapshot
/// events) so a viewer whose tab closed without a clean dispose still
/// drops off the list once their heartbeat goes stale.
class PresenceNotifier extends StateNotifier<List<Member>> {
  final FirebaseFirestore db;
  final String boardId;
  static const _staleAfter = Duration(seconds: 25);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  Timer? _sweepTimer;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  PresenceNotifier(this.db, this.boardId) : super([]) {
    _sub = db
        .collection('boards')
        .doc(boardId)
        .collection('presence')
        .snapshots()
        .listen(
          (snap) {
            _docs = snap.docs;
            _recompute();
          },
          onError: (_) {},
        );
    _sweepTimer = Timer.periodic(const Duration(seconds: 8), (_) => _recompute());
  }

  void _recompute() {
    final cutoff = DateTime.now().subtract(_staleAfter);
    state = [
      for (final doc in _docs)
        if (((doc.data()['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime(0))
            .isAfter(cutoff))
          memberFromMap(doc.data()),
    ];
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sweepTimer?.cancel();
    super.dispose();
  }
}

final presenceProvider = StateNotifierProvider.autoDispose.family<PresenceNotifier, List<Member>, String>((
  ref,
  boardId,
) {
  return PresenceNotifier(ref.watch(firestoreProvider), boardId);
});

/// Writes/refreshes a presence heartbeat doc while a board screen is
/// open, and removes it on dispose. Firestore has no native
/// disconnect-detection (unlike Realtime Database), so [PresenceNotifier]
/// also ages out stale heartbeats client-side as a fallback.
class PresenceHeartbeat {
  final FirebaseFirestore db;
  final String boardId;
  final Member member;
  Timer? _timer;

  PresenceHeartbeat({required this.db, required this.boardId, required this.member});

  DocumentReference<Map<String, dynamic>> get _doc =>
      db.collection('boards').doc(boardId).collection('presence').doc(member.id);

  void start() {
    _beat();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _beat());
  }

  void _beat() {
    _doc.set({
      ...memberToMap(member),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  void stop() {
    _timer?.cancel();
    _doc.delete();
  }
}
