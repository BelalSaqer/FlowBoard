import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/activity_entry.dart';
import '../models/board.dart';
import '../models/board_column.dart';
import '../models/comment.dart';
import '../models/member.dart';
import '../models/priority.dart';
import '../models/subtask.dart';
import '../models/task_card.dart';

Map<String, dynamic> memberToMap(Member m) => {
  'id': m.id,
  'name': m.name,
  'initials': m.initials,
  'color': m.color.toARGB32(),
};

Member memberFromMap(Map<String, dynamic> map) => Member(
  id: map['id'] as String,
  name: map['name'] as String,
  initials: map['initials'] as String,
  color: Color(map['color'] as int),
);

Board boardFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;
  final members = [
    for (final m in (data['members'] as List<dynamic>? ?? []))
      memberFromMap(Map<String, dynamic>.from(m as Map)),
  ];
  return Board(
    id: doc.id,
    name: data['name'] as String,
    color: Color(data['color'] as int? ?? 0xFF6C5CE7),
    members: members,
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    // Seeded boards predate the ownerId field; fall back to the first
    // member so older docs still resolve an owner.
    ownerId: data['ownerId'] as String? ?? (members.isNotEmpty ? members.first.id : ''),
    roles: {
      for (final entry in (data['roles'] as Map<String, dynamic>? ?? {}).entries)
        entry.key: entry.value as String,
    },
    linkJoinEnabled: data['linkJoinEnabled'] as bool? ?? false,
  );
}

Map<String, dynamic> boardToMap(Board b) => {
  'name': b.name,
  'color': b.color.toARGB32(),
  'members': [for (final m in b.members) memberToMap(m)],
  // Denormalized alongside `members` purely so security rules can check
  // membership cheaply (`uid in memberIds`) without decoding the member
  // map list.
  'memberIds': [for (final m in b.members) m.id],
  'ownerId': b.ownerId,
  'roles': b.roles,
  'updatedAt': FieldValue.serverTimestamp(),
};

Map<String, dynamic> subtaskToMap(SubTask s) => {
  'id': s.id,
  'text': s.text,
  'done': s.done,
};

SubTask subtaskFromMap(Map<String, dynamic> map) => SubTask(
  id: map['id'] as String,
  text: map['text'] as String,
  done: map['done'] as bool? ?? false,
);

Map<String, dynamic> commentToMap(TaskComment c) => {
  'id': c.id,
  'author': memberToMap(c.author),
  'time': Timestamp.fromDate(c.time),
  'body': c.body,
};

TaskComment commentFromMap(Map<String, dynamic> map) => TaskComment(
  id: map['id'] as String,
  author: memberFromMap(Map<String, dynamic>.from(map['author'] as Map)),
  time: (map['time'] as Timestamp).toDate(),
  body: map['body'] as String,
);

Map<String, dynamic> activityToMap(ActivityEntry a) => {
  'id': a.id,
  'text': a.text,
  'time': Timestamp.fromDate(a.time),
  'dotColor': a.dotColor.toARGB32(),
};

ActivityEntry activityFromMap(Map<String, dynamic> map) => ActivityEntry(
  id: map['id'] as String,
  text: map['text'] as String,
  time: (map['time'] as Timestamp).toDate(),
  dotColor: Color(map['dotColor'] as int),
);

BoardColumnId columnFromString(String s) =>
    BoardColumnId.values.firstWhere((c) => c.name == s);

Priority priorityFromString(String s) =>
    Priority.values.firstWhere((p) => p.name == s);

/// A task document also carries `order` (fractional index within its
/// column, used for drag-reordering) and `updatedBy` (who last wrote to
/// it, used for conflict detection) — both read here but not modeled on
/// [TaskCard] itself, since they're sync-layer concerns, not UI state.
class TaskDoc {
  final TaskCard task;
  final double order;
  final Member? updatedBy;
  final DateTime? updatedAt;

  const TaskDoc({
    required this.task,
    required this.order,
    this.updatedBy,
    this.updatedAt,
  });
}

TaskDoc taskDocFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;
  final task = TaskCard(
    id: doc.id,
    title: data['title'] as String,
    description: data['description'] as String? ?? '',
    priority: priorityFromString(data['priority'] as String),
    assignee: memberFromMap(Map<String, dynamic>.from(data['assignee'] as Map)),
    dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
    column: columnFromString(data['column'] as String),
    subtasks: [
      for (final s in (data['subtasks'] as List<dynamic>? ?? []))
        subtaskFromMap(Map<String, dynamic>.from(s as Map)),
    ],
    comments: [
      for (final c in (data['comments'] as List<dynamic>? ?? []))
        commentFromMap(Map<String, dynamic>.from(c as Map)),
    ],
    activity: [
      for (final a in (data['activity'] as List<dynamic>? ?? []))
        activityFromMap(Map<String, dynamic>.from(a as Map)),
    ],
    labels: [
      for (final l in (data['labels'] as List<dynamic>? ?? [])) l as String,
    ],
    attachments: [
      for (final a in (data['attachments'] as List<dynamic>? ?? [])) a as String,
    ],
  );
  return TaskDoc(
    task: task,
    order: (data['order'] as num?)?.toDouble() ?? 0,
    updatedBy: data['updatedBy'] != null
        ? memberFromMap(Map<String, dynamic>.from(data['updatedBy'] as Map))
        : null,
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
  );
}

Map<String, dynamic> taskToSeedMap(TaskCard t, double order) => {
  'title': t.title,
  'description': t.description,
  'priority': t.priority.name,
  'assignee': memberToMap(t.assignee),
  'dueDate': t.dueDate != null ? Timestamp.fromDate(t.dueDate!) : null,
  'column': t.column.name,
  'order': order,
  'subtasks': [for (final s in t.subtasks) subtaskToMap(s)],
  'comments': [for (final c in t.comments) commentToMap(c)],
  'activity': [for (final a in t.activity) activityToMap(a)],
  'labels': t.labels,
  'attachments': t.attachments,
  'updatedAt': FieldValue.serverTimestamp(),
  'updatedBy': null,
};
