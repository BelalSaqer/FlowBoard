import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import '../providers/boards_provider.dart';
import '../services/deep_link.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_back_button.dart';
import '../widgets/member_role_row.dart';
import 'auth_gate.dart';

const _boardPalette = [
  AppColors.primary,
  AppColors.primaryLight,
  AppColors.priorityHigh,
  AppColors.priorityMedium,
  AppColors.priorityLowAlt,
  AppColors.accentPink,
  AppColors.success,
  AppColors.textMutedLight,
];

class BoardSettingsScreen extends ConsumerStatefulWidget {
  final Board board;
  const BoardSettingsScreen({super.key, required this.board});

  @override
  ConsumerState<BoardSettingsScreen> createState() => _BoardSettingsScreenState();
}

class _BoardSettingsScreenState extends ConsumerState<BoardSettingsScreen> {
  late final _nameController = TextEditingController(text: widget.board.name);
  late Color _color = widget.board.color;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && name != widget.board.name) {
      ref.read(boardsProvider.notifier).renameBoard(widget.board.id, name);
    }
  }

  void _pickColor(Color c) {
    setState(() => _color = c);
    ref.read(boardsProvider.notifier).recolorBoard(widget.board.id, c);
  }

  Future<void> _archive() async {
    final confirmed = await _confirm(
      title: 'Archive board?',
      body: 'Hides "${widget.board.name}" from everyone. You can restore it later from Firestore — a restore UI is coming soon.',
      confirmLabel: 'Archive',
    );
    if (confirmed != true || !mounted) return;
    await ref.read(boardsProvider.notifier).archiveBoard(widget.board.id);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _delete() async {
    final confirmed = await _confirm(
      title: 'Delete board?',
      body: 'Permanently deletes "${widget.board.name}" and all its tasks. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(boardsProvider.notifier);
    final snapshot = await notifier.snapshotForUndo(widget.board.id);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);

    final controller = scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('"${widget.board.name}" deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        duration: const Duration(seconds: 5),
      ),
    );
    final reason = await controller?.closed;
    if (reason == SnackBarClosedReason.action) {
      await notifier.restoreBoard(snapshot);
    } else {
      await notifier.deleteBoard(widget.board.id);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel, style: TextStyle(color: destructive ? AppColors.priorityHigh : AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = ref.watch(boardsProvider).firstWhere(
          (b) => b.id == widget.board.id,
          orElse: () => widget.board,
        );
    final myId = ref.watch(currentMemberStateProvider)?.id;
    final isOwner = myId != null && myId == board.ownerId;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Text('Board settings', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel('BOARD NAME'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _nameController,
                  style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  onSubmitted: (_) => _saveName(),
                  onTapOutside: (_) => _saveName(),
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel('BOARD COLOR'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in _boardPalette)
                    InkWell(
                      onTap: () => _pickColor(c),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(12),
                          border: _color.toARGB32() == c.toARGB32()
                              ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  _SectionLabel('MEMBERS'),
                  const Spacer(),
                  Text(
                    'tap role to change',
                    style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final m in board.members)
                MemberRoleRow(
                  member: m,
                  role: board.roleOf(m.id),
                  onRoleTap: (isOwner && m.id != board.ownerId)
                      ? () async {
                          final picked = await showRolePickerDialog(context, board.roleOf(m.id));
                          if (picked != null) {
                            await ref.read(boardsProvider.notifier).setMemberRole(board.id, m.id, picked);
                          }
                        }
                      : null,
                ),
              if (isOwner) ...[
                const SizedBox(height: 30),
                Text(
                  'DANGER ZONE',
                  style: AppTextStyles.meta(color: AppColors.priorityHigh).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
                const SizedBox(height: 10),
                _DangerAction(
                  title: 'Archive board',
                  subtitle: 'Hide it from everyone. Restorable later from Boards → Archived.',
                  onTap: _archive,
                ),
                const SizedBox(height: 10),
                _DangerAction(
                  title: 'Delete board',
                  subtitle: 'Permanent. All tasks and their history go too.',
                  filled: true,
                  onTap: _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
    );
  }
}

class _DangerAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;
  const _DangerAction({required this.title, required this.subtitle, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled ? AppColors.priorityHighBg : null,
          border: filled ? null : Border.all(color: AppColors.priorityHigh.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.bodyLarge(color: AppColors.priorityHigh).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, style: AppTextStyles.bodySmall(color: AppColors.priorityHighText)),
          ],
        ),
      ),
    );
  }
}
