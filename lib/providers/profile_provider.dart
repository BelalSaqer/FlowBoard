import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/firestore_mappers.dart';
import '../data/personas.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import 'auth_provider.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Ensures a `users/{uid}` profile document exists for the signed-in user
/// and resolves to that user's [Member] representation. Anonymous users
/// get a random persona (name/initials/color) so a handful of guest tabs
/// look like distinct collaborators; real accounts use their Google
/// display name with a color derived deterministically from their uid.
final currentMemberProvider = FutureProvider<Member>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    throw StateError('currentMemberProvider read while signed out');
  }

  final db = ref.watch(firestoreProvider);
  final docRef = db.collection('users').doc(user.uid);
  final email = user.email?.trim().toLowerCase();
  final existing = await docRef.get();
  if (existing.exists) {
    // Backfill email for accounts created before invite-by-email existed.
    if (email != null && email.isNotEmpty && existing.data()?['email'] != email) {
      await docRef.set({'email': email}, SetOptions(merge: true));
    }
    return memberFromMap(existing.data()!);
  }

  final Member member;
  if (user.isAnonymous) {
    final persona = personaPool[Random().nextInt(personaPool.length)];
    member = Member(id: user.uid, name: persona.name, initials: persona.initials, color: persona.color);
  } else {
    final name = (user.displayName?.trim().isNotEmpty ?? false) ? user.displayName!.trim() : 'Member';
    member = Member(
      id: user.uid,
      name: name,
      initials: initialsFor(name),
      color: AppColors.avatarPalette[user.uid.hashCode.abs() % AppColors.avatarPalette.length],
    );
  }

  await docRef.set({
    ...memberToMap(member),
    if (email != null && email.isNotEmpty) 'email': email,
    'createdAt': FieldValue.serverTimestamp(),
  });
  return member;
});

/// Looks up a signed-in user by their stored email (Google accounts
/// only — guests have none). Returns null if no account matches.
Future<Member?> findMemberByEmail(FirebaseFirestore db, String email) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  final snap = await db.collection('users').where('email', isEqualTo: normalized).limit(1).get();
  if (snap.docs.isEmpty) return null;
  return memberFromMap(snap.docs.first.data());
}

/// Looks up a signed-in user by their reserved username (works for any
/// account type, including guests, since a username isn't tied to an
/// email provider). Returns null if no account matches.
Future<Member?> findMemberByUsername(FirebaseFirestore db, String username) async {
  final normalized = username.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  final mapping = await db.collection('usernames').doc(normalized).get();
  if (!mapping.exists) return null;
  final uid = mapping.data()!['uid'] as String;
  final userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) return null;
  return memberFromMap(userDoc.data()!);
}

final _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

/// Attempts to reserve [desired] for [uid], releasing [previousUsername]
/// (if any) once the new one is secured. Returns null on success, or a
/// user-facing error string. The reservation doc's `create`-only rule is
/// what actually makes this race-safe against two users claiming the
/// same name at once — the pre-check here is just for a nicer error
/// message on the common case.
Future<String?> claimUsername(FirebaseFirestore db, String uid, String desired, {String? previousUsername}) async {
  final normalized = desired.trim().toLowerCase();
  if (!_usernamePattern.hasMatch(normalized)) {
    return 'Usernames must be 3-20 characters: letters, numbers, and underscores only.';
  }
  if (normalized == previousUsername) return null;

  final ref = db.collection('usernames').doc(normalized);
  final existing = await ref.get();
  if (existing.exists) {
    // Reserved by someone else: a real conflict. Reserved by this same
    // uid already: most likely a previous attempt got interrupted after
    // claiming the name but before finishing (e.g. the tab closed) —
    // treat it as success rather than telling the user their own name
    // is taken and leaving them unable to ever use it.
    if (existing.data()?['uid'] != uid) {
      return 'That username is already taken.';
    }
  } else {
    try {
      await ref.set({'uid': uid});
    } catch (_) {
      return 'That username is already taken.';
    }
  }
  if (previousUsername != null && previousUsername.isNotEmpty && previousUsername != normalized) {
    try {
      await db.collection('usernames').doc(previousUsername).delete();
    } catch (e) {
      // Best-effort cleanup of the old reservation — not fatal if it
      // fails (the new username is already claimed either way), but
      // logged so an old username silently never getting released isn't
      // completely invisible.
      debugPrint('claimUsername: failed to release previous username "$previousUsername": $e');
    }
  }
  await db.collection('users').doc(uid).set({'username': normalized}, SetOptions(merge: true));
  return null;
}

/// Live avatar photo for [uid], watched by [MemberAvatar] so a photo set
/// on the profile screen shows up everywhere that member is rendered —
/// task cards, comments, presence, invite lists — without needing to be
/// denormalized into every place a [Member] snapshot is stored.
final memberPhotoProvider = StreamProvider.autoDispose.family<String?, String>((ref, uid) {
  final db = ref.watch(firestoreProvider);
  return db.collection('users').doc(uid).snapshots().map((s) => s.data()?['photoBase64'] as String?);
});

String initialsFor(String name) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, min(2, parts.first.length)).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
