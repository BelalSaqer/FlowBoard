import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowboard/data/saved_filters.dart';
import 'package:flowboard/models/priority.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saveSavedFilters then loadSavedFilters round-trips every field', () async {
    final filters = [
      const SavedFilter(
        name: 'My overdue high priority',
        priorities: {Priority.high},
        assigneeIds: {'alice'},
        overdue: true,
        dueSoon: false,
      ),
    ];

    await saveSavedFilters('board-1', filters);
    final loaded = await loadSavedFilters('board-1');

    expect(loaded, hasLength(1));
    expect(loaded.first.name, 'My overdue high priority');
    expect(loaded.first.priorities, {Priority.high});
    expect(loaded.first.assigneeIds, {'alice'});
    expect(loaded.first.overdue, isTrue);
    expect(loaded.first.dueSoon, isFalse);
  });

  test('saved filters are scoped per board', () async {
    await saveSavedFilters('board-1', const [
      SavedFilter(name: 'A', priorities: {}, assigneeIds: {}, overdue: false, dueSoon: false),
    ]);

    final other = await loadSavedFilters('board-2');
    expect(other, isEmpty);
  });

  test('loadSavedFilters returns an empty list when nothing was saved yet', () async {
    final loaded = await loadSavedFilters('never-saved');
    expect(loaded, isEmpty);
  });
}
