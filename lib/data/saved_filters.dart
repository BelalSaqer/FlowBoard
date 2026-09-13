import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/priority.dart';

/// A named combination of search filters, saved per-device (not synced
/// via Firestore — this is a personal convenience, not board data other
/// members need to see) and scoped per-board, since assignee ids only
/// make sense within one board's member list.
class SavedFilter {
  final String name;
  final Set<Priority> priorities;
  final Set<String> assigneeIds;
  final bool overdue;
  final bool dueSoon;

  const SavedFilter({
    required this.name,
    required this.priorities,
    required this.assigneeIds,
    required this.overdue,
    required this.dueSoon,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'priorities': [for (final p in priorities) p.name],
    'assigneeIds': assigneeIds.toList(),
    'overdue': overdue,
    'dueSoon': dueSoon,
  };

  factory SavedFilter.fromJson(Map<String, dynamic> json) => SavedFilter(
    name: json['name'] as String,
    priorities: {
      for (final p in (json['priorities'] as List<dynamic>? ?? []))
        Priority.values.firstWhere((v) => v.name == p, orElse: () => Priority.medium),
    },
    assigneeIds: {for (final a in (json['assigneeIds'] as List<dynamic>? ?? [])) a as String},
    overdue: json['overdue'] as bool? ?? false,
    dueSoon: json['dueSoon'] as bool? ?? false,
  );
}

String _prefsKey(String boardId) => 'savedFilters_$boardId';

Future<List<SavedFilter>> loadSavedFilters(String boardId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey(boardId));
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return [for (final e in list) SavedFilter.fromJson(e as Map<String, dynamic>)];
  } catch (_) {
    return [];
  }
}

Future<void> saveSavedFilters(String boardId, List<SavedFilter> filters) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey(boardId), jsonEncode([for (final f in filters) f.toJson()]));
}
