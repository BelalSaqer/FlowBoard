import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board.dart';
import '../providers/boards_provider.dart';
import '../providers/profile_provider.dart';
import '../screens/auth_gate.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import 'member_role_row.dart';

/// Shareable board link + member list, plus real add-by-email. The link
/// scheme (flowboard.app/b/{boardId}) is still a placeholder — it isn't a
/// real deep link yet since there's no invite/join backend — but adding
/// an existing account by email is real: it looks the person up by their
/// stored `users/{uid}.email` and adds them to the board's member list.
class InviteSheet extends ConsumerStatefulWidget {
  final Board board;
  const InviteSheet({super.key, required this.board});

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  String get _link => 'flowboard.app/b/${widget.board.id}';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addMember(Board board) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Enter an email address.';
        _success = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    final db = ref.read(firestoreProvider);
    final found = await findMemberByEmail(db, email);

    if (found == null) {
      setState(() {
        _busy = false;
        _error = 'No account found for that email.';
      });
      return;
    }
    if (board.members.any((m) => m.id == found.id)) {
      setState(() {
        _busy = false;
        _error = '${found.name} is already a member.';
      });
      return;
    }

    await ref.read(boardsProvider.notifier).addMember(board.id, found);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _success = 'Added ${found.name} to the board.';
    });
    _emailController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch the live board so a newly added member shows up immediately
    // without needing to reopen the sheet.
    final board = ref.watch(boardsProvider).firstWhere(
          (b) => b.id == widget.board.id,
          orElse: () => widget.board,
        );

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.modalTop)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 38, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Invite to board', style: AppTextStyles.h2(color: theme.colorScheme.onSurface)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text('Done', style: AppTextStyles.body(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)).copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              Text(
                '${board.name} · anyone with the link can edit',
                style: AppTextStyles.metaMedium(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              Text('INVITE LINK', style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _link,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: 'https://$_link'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      child: Text('Copy Link', style: AppTextStyles.bodySmall(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('ADD MEMBER', style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              Text(
                'Only works for people who\'ve signed in with Google — guests have no email on file.',
                style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.45)).copyWith(height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'person@company.com',
                          hintStyle: AppTextStyles.bodySmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                        ),
                        onSubmitted: (_) => _addMember(board),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _addMember(board),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Add', style: AppTextStyles.bodySmall(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: AppTextStyles.bodySmall(color: AppColors.priorityHigh)),
              ],
              if (_success != null) ...[
                const SizedBox(height: 8),
                Text(_success!, style: AppTextStyles.bodySmall(color: AppColors.success)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('BOARD MEMBERS', style: AppTextStyles.meta(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                  const Spacer(),
                  Text(
                    '${board.members.length} people',
                    style: AppTextStyles.metaSmall(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final m in board.members)
                MemberRoleRow(
                  member: m,
                  role: board.roleOf(m.id),
                  onRoleTap: (ref.watch(currentMemberStateProvider)?.id == board.ownerId && m.id != board.ownerId)
                      ? () async {
                          final picked = await showRolePickerDialog(context, board.roleOf(m.id));
                          if (picked != null) {
                            await ref.read(boardsProvider.notifier).setMemberRole(board.id, m.id, picked);
                          }
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
