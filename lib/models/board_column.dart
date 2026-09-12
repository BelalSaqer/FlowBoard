enum BoardColumnId {
  todo,
  inProgress,
  done;

  String get label => switch (this) {
    BoardColumnId.todo => 'To Do',
    BoardColumnId.inProgress => 'In Progress',
    BoardColumnId.done => 'Done',
  };

  String get emptyLabel => switch (this) {
    BoardColumnId.todo => 'Column is clear',
    BoardColumnId.inProgress => 'No work in flight',
    BoardColumnId.done => 'Nothing finished yet',
  };
}
