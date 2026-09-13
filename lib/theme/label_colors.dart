import 'package:flutter/material.dart';

/// A small fixed palette of preset task labels, each with its own color —
/// deliberately a closed set (not free-form tagging) so label chips stay
/// visually consistent across a board rather than turning into a wall of
/// randomly-colored text.
const Map<String, Color> presetLabelColors = {
  'Bug': Color(0xFFE0523A),
  'Feature': Color(0xFF6C5CE7),
  'Design': Color(0xFFE0559E),
  'Backend': Color(0xFF2F80ED),
  'Frontend': Color(0xFF3B9E77),
  'Docs': Color(0xFFB98900),
  'Urgent': Color(0xFFC0392B),
};

Color labelColor(String label) => presetLabelColors[label] ?? const Color(0xFF8C88A8);
