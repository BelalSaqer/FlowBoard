import 'package:flutter/material.dart';

class ActivityEntry {
  final String id;
  final String text;
  final DateTime time;
  final Color dotColor;

  const ActivityEntry({
    required this.id,
    required this.text,
    required this.time,
    required this.dotColor,
  });
}
