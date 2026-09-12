import 'package:flutter/material.dart';

/// A workspace member. Also doubles as a presence/assignee avatar source.
class Member {
  final String id;
  final String name;
  final String initials;
  final Color color;

  const Member({
    required this.id,
    required this.name,
    required this.initials,
    required this.color,
  });
}
