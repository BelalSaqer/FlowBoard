import '../models/activity_entry.dart';
import '../models/board.dart';
import '../models/board_column.dart';
import '../models/comment.dart';
import '../models/member.dart';
import '../models/priority.dart';
import '../models/task_card.dart';
import '../theme/app_colors.dart';

/// Static seed data standing in for the Firestore-backed repository.
/// Swap this out for real-time Firestore streams once the Firebase
/// project is wired up — the provider layer already reads through
/// notifiers so screens won't need to change.
class MockData {
  MockData._();

  static const ana = Member(
    id: 'ar',
    name: 'Ana Ruiz',
    initials: 'AR',
    color: AppColors.primary,
  );
  static const milo = Member(
    id: 'ms',
    name: 'Milo Sato',
    initials: 'MS',
    color: AppColors.priorityHigh,
  );
  static const jun = Member(
    id: 'jl',
    name: 'Jun Lee',
    initials: 'JL',
    color: AppColors.priorityLow,
  );
  static const rae = Member(
    id: 'rk',
    name: 'Rae Kim',
    initials: 'RK',
    color: AppColors.priorityMedium,
  );
  static const theo = Member(
    id: 'tc',
    name: 'Theo Cole',
    initials: 'TC',
    color: AppColors.accentPink,
  );
  static const you = Member(
    id: 'me',
    name: 'You',
    initials: 'YOU',
    color: AppColors.primary,
  );

  static const members = [ana, milo, jun, rae, theo];

  static final boards = [
    Board(
      id: 'b1',
      name: 'Mobile App v2',
      color: AppColors.primary,
      members: [milo, jun, ana, rae],
      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ownerId: ana.id,
    ),
    Board(
      id: 'b2',
      name: 'Design System',
      color: AppColors.priorityHigh,
      members: [theo, ana],
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ownerId: theo.id,
    ),
    Board(
      id: 'b3',
      name: 'Q4 Marketing',
      color: AppColors.priorityMedium,
      members: [rae, milo, theo],
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ownerId: rae.id,
    ),
    Board(
      id: 'b4',
      name: 'Research Backlog',
      color: AppColors.priorityLow,
      members: [jun],
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ownerId: jun.id,
    ),
  ];

  /// Who's currently viewing each board (mock presence).
  static const Map<String, List<Member>> presenceByBoard = {
    'b1': [milo, jun, rae, theo, ana],
    'b2': [theo],
    'b3': [rae, milo],
    'b4': [],
  };

  static Map<BoardColumnId, List<TaskCard>> tasksForBoard(String boardId) {
    if (boardId != 'b1') {
      return {
        BoardColumnId.todo: [],
        BoardColumnId.inProgress: [],
        BoardColumnId.done: [],
      };
    }
    return {
      BoardColumnId.todo: [
        TaskCard(
          id: 't1',
          title: 'Refine onboarding copy',
          description:
              'Tighten the three intro screens and cut the second CTA.',
          priority: Priority.medium,
          assignee: ana,
          dueDate: DateTime(2026, 9, 18),
          column: BoardColumnId.todo,
          activity: [
            ActivityEntry(
              id: 'a1',
              text: 'Ana created this card',
              time: DateTime.now().subtract(const Duration(days: 2)),
              dotColor: AppColors.primary,
            ),
          ],
        ),
        TaskCard(
          id: 't2',
          title: 'Empty states for offline mode',
          description:
              'Placeholder + retry action for every list view when the socket drops.',
          priority: Priority.low,
          assignee: rae,
          dueDate: DateTime(2026, 9, 22),
          column: BoardColumnId.todo,
        ),
        TaskCard(
          id: 't3',
          title: 'Audit color contrast',
          description: 'Priority tags fail 4.5:1 on the dark surface.',
          priority: Priority.low,
          assignee: theo,
          dueDate: DateTime(2026, 9, 25),
          column: BoardColumnId.todo,
          comments: [
            TaskComment(
              id: 'c0',
              author: theo,
              time: DateTime.now().subtract(const Duration(hours: 5)),
              body: 'Flagging this before it ships in the dark theme pass.',
            ),
          ],
        ),
      ],
      BoardColumnId.inProgress: [
        TaskCard(
          id: 't4',
          title: 'Realtime cursor presence',
          description:
              'Sync avatar positions over the websocket channel and fade idle viewers.',
          priority: Priority.high,
          assignee: milo,
          dueDate: DateTime(2026, 9, 15),
          column: BoardColumnId.inProgress,
          comments: [
            TaskComment(
              id: 'c1',
              author: milo,
              time: DateTime(2026, 9, 11, 14, 2),
              body:
                  'Interpolation is in. Still seeing a jump when a viewer reconnects — I think we replay the last packet twice.',
            ),
            TaskComment(
              id: 'c2',
              author: jun,
              time: DateTime(2026, 9, 11, 14, 20),
              body:
                  'Dedupe on packet id should fix it. I can pick that up after the drag profiling.',
            ),
          ],
          activity: [
            ActivityEntry(
              id: 'a2',
              text: 'Milo moved this card to In Progress',
              time: DateTime(2026, 9, 11, 13, 41),
              dotColor: AppColors.primary,
            ),
            ActivityEntry(
              id: 'a3',
              text: 'Jun changed priority from Medium to High',
              time: DateTime(2026, 9, 11, 11, 8),
              dotColor: AppColors.priorityHigh,
            ),
            ActivityEntry(
              id: 'a4',
              text: 'Ana attached the websocket RFC',
              time: DateTime(2026, 9, 10, 17, 22),
              dotColor: AppColors.priorityLow,
            ),
          ],
        ),
        TaskCard(
          id: 't5',
          title: 'Board drag performance',
          description:
              'Frame drops on columns with more than forty cards during drag.',
          priority: Priority.medium,
          assignee: jun,
          dueDate: DateTime(2026, 9, 19),
          column: BoardColumnId.inProgress,
        ),
      ],
      BoardColumnId.done: [
        TaskCard(
          id: 't6',
          title: 'Ship push notifications',
          description: 'Mentions and assignment events, batched per board.',
          priority: Priority.high,
          assignee: ana,
          dueDate: DateTime(2026, 9, 4),
          column: BoardColumnId.done,
        ),
        TaskCard(
          id: 't7',
          title: 'Settings screen polish',
          description: 'Grouped rows, new switch component.',
          priority: Priority.low,
          assignee: milo,
          dueDate: DateTime(2026, 9, 2),
          column: BoardColumnId.done,
        ),
      ],
    };
  }
}
