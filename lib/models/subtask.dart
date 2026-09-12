class SubTask {
  final String id;
  final String text;
  final bool done;

  const SubTask({required this.id, required this.text, this.done = false});

  SubTask copyWith({bool? done}) =>
      SubTask(id: id, text: text, done: done ?? this.done);
}
