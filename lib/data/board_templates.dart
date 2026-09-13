import '../models/board_column.dart';
import '../models/priority.dart';

/// One starter card in a [BoardTemplate] — assigned to whoever creates the
/// board (a template can't know who else will join yet).
class TemplateTask {
  final BoardColumnId column;
  final String title;
  final String description;
  final Priority priority;
  const TemplateTask({
    required this.column,
    required this.title,
    this.description = '',
    this.priority = Priority.medium,
  });
}

class BoardTemplate {
  final String name;
  final String description;
  final List<TemplateTask> tasks;
  const BoardTemplate({required this.name, required this.description, this.tasks = const []});
}

/// Starter presets offered when creating a board — a blank one (today's
/// only option) plus a few populated ones so a new board isn't always
/// three empty columns. Purely client-side data; picking one just seeds
/// a handful of real task documents at creation time.
const boardTemplates = [
  BoardTemplate(name: 'Blank', description: 'Three empty columns.'),
  BoardTemplate(
    name: 'Sprint board',
    description: 'Plan, work, and ship a two-week sprint.',
    tasks: [
      TemplateTask(column: BoardColumnId.todo, title: 'Write sprint goal', priority: Priority.high),
      TemplateTask(column: BoardColumnId.todo, title: 'Groom backlog', priority: Priority.medium),
      TemplateTask(column: BoardColumnId.todo, title: 'Estimate story points', priority: Priority.medium),
      TemplateTask(column: BoardColumnId.inProgress, title: 'Daily standup notes', priority: Priority.low),
      TemplateTask(column: BoardColumnId.done, title: 'Sprint kickoff', priority: Priority.medium),
    ],
  ),
  BoardTemplate(
    name: 'Content calendar',
    description: 'Plan and track posts from idea to published.',
    tasks: [
      TemplateTask(column: BoardColumnId.todo, title: 'Brainstorm post ideas', priority: Priority.low),
      TemplateTask(column: BoardColumnId.todo, title: 'Draft outline', priority: Priority.medium),
      TemplateTask(column: BoardColumnId.inProgress, title: 'Write first draft', priority: Priority.medium),
      TemplateTask(column: BoardColumnId.inProgress, title: 'Design cover image', priority: Priority.low),
      TemplateTask(column: BoardColumnId.done, title: 'Content calendar created', priority: Priority.low),
    ],
  ),
  BoardTemplate(
    name: 'Bug tracker',
    description: 'Triage, fix, and verify issues.',
    tasks: [
      TemplateTask(column: BoardColumnId.todo, title: 'Triage new reports', priority: Priority.high),
      TemplateTask(column: BoardColumnId.todo, title: 'Reproduce and label severity', priority: Priority.medium),
      TemplateTask(column: BoardColumnId.inProgress, title: 'Fix and add a regression test', priority: Priority.high),
      TemplateTask(column: BoardColumnId.done, title: 'Bug tracker created', priority: Priority.low),
    ],
  ),
];
