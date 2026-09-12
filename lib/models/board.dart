import 'package:flutter/material.dart';
import 'member.dart';

class Board {
  final String id;
  final String name;
  final Color color;
  final List<Member> members;
  final DateTime updatedAt;
  final String ownerId;
  final Map<String, String> roles;

  const Board({
    required this.id,
    required this.name,
    required this.color,
    required this.members,
    required this.updatedAt,
    required this.ownerId,
    this.roles = const {},
  });

  /// 'owner', 'editor', or 'viewer'. The owner always resolves to 'owner'
  /// regardless of what's in [roles]; everyone else defaults to 'editor'
  /// until explicitly demoted.
  String roleOf(String uid) {
    if (uid == ownerId) return 'owner';
    return roles[uid] ?? 'editor';
  }
}
