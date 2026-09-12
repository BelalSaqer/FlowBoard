import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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

String initialsFor(String name) {
  final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, min(2, parts.first.length)).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
