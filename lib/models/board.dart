import 'package:flutter/material.dart';
import 'member.dart';

class Board {
  final String id;
  final String name;
  final Color color;
  final List<Member> members;
  final DateTime updatedAt;
  final String ownerId;

  const Board({
    required this.id,
    required this.name,
    required this.color,
    required this.members,
    required this.updatedAt,
    required this.ownerId,
  });
}
