import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/data/firestore_mappers.dart';
import 'package:flowboard/models/board_column.dart';
import 'package:flowboard/models/priority.dart';

void main() {
  group('columnFromString', () {
    test('parses every known column name', () {
      for (final c in BoardColumnId.values) {
        expect(columnFromString(c.name), c);
      }
    });

    test('falls back to todo instead of throwing on an unrecognized value', () {
      expect(columnFromString('archived'), BoardColumnId.todo);
      expect(columnFromString(''), BoardColumnId.todo);
    });
  });

  group('priorityFromString', () {
    test('parses every known priority name', () {
      for (final p in Priority.values) {
        expect(priorityFromString(p.name), p);
      }
    });

    test('falls back to medium instead of throwing on an unrecognized value', () {
      expect(priorityFromString('urgent'), Priority.medium);
      expect(priorityFromString(''), Priority.medium);
    });
  });
}
