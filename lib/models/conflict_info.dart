import 'member.dart';

/// Describes a concurrent-edit conflict that was resolved by taking the
/// latest write. Surfaced as a dismissible inline banner on the task sheet
/// rather than silently overwritten.
class ConflictInfo {
  final Member editedBy;
  final DateTime at;

  const ConflictInfo({required this.editedBy, required this.at});

  String get message => '${editedBy.name} also edited this card — showing the latest version';
}
