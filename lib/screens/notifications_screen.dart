import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import '../models/notification_entry.dart';
import '../providers/boards_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/member_avatar.dart';
import 'auth_gate.dart';
import 'board_detail_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifsAsync = ref.watch(notificationsProvider);
    final me = ref.watch(currentMemberStateProvider);

    return Scaffold(
      body: SafeArea(
        child: notifsAsync.when(
          data: (notifs) {
            final unread = notifs.where((n) => !n.read).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifications', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                            Text(
                              '${unread.length} unread',
                              style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      if (unread.isNotEmpty && me != null)
                        TextButton(
                          onPressed: () => markAllNotificationsRead(ref.read(firestoreProvider), me.id, unread),
                          child: Text('Mark all read', style: AppTextStyles.body(color: AppColors.primary).copyWith(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: notifs.isEmpty
                      ? Center(
                          child: Text('No notifications yet', style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                          itemCount: notifs.length,
                          itemBuilder: (context, i) => _NotificationTile(entry: notifs[i]),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationEntry entry;
  const _NotificationTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.read(currentMemberStateProvider);

    return InkWell(
      onTap: () async {
        if (!entry.read && me != null) {
          markNotificationRead(ref.read(firestoreProvider), me.id, entry.id);
        }
        final boards = ref.read(boardsProvider);
        Board? board;
        for (final b in boards) {
          if (b.id == entry.boardId) board = b;
        }
        if (board != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BoardDetailScreen(board: board!)),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: entry.read ? Colors.transparent : AppColors.primaryTint.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                MemberAvatar(member: entry.actor, size: 40),
                if (!entry.read)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(height: 1.4),
                      children: [
                        TextSpan(text: '${entry.actor.name} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: entry.type == NotificationType.comment ? 'commented on a task assigned to you' : 'assigned you'),
                        TextSpan(text: " '${entry.taskTitle}'", style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(_relativeTime(entry.createdAt), style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d ago';
}
