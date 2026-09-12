import 'package:flutter/material.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'member_avatar.dart';

/// A member's role relative to a board: 'owner', 'editor', or 'viewer'.
/// Owner is derived from the board's `ownerId` and can't be changed;
/// editor/viewer is real, rule-enforced state the board owner can toggle.
class RoleBadge extends StatelessWidget {
  final String role;
  final VoidCallback? onTap;

  const RoleBadge({super.key, required this.role, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = role == 'owner';
    final label = role[0].toUpperCase() + role.substring(1);
    return InkWell(
      onTap: isOwner ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isOwner ? AppColors.primaryTint : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodySmall(
                color: isOwner ? AppColors.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            if (!isOwner && onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Avatar + name + [RoleBadge] row, reused by both the board settings
/// member list and the invite sheet.
class MemberRoleRow extends StatelessWidget {
  final Member member;
  final String role;
  final VoidCallback? onRoleTap;

  const MemberRoleRow({super.key, required this.member, required this.role, this.onRoleTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          MemberAvatar(member: member, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(member.name, style: AppTextStyles.bodyLarge(color: theme.colorScheme.onSurface).copyWith(fontWeight: FontWeight.w600)),
          ),
          RoleBadge(role: role, onTap: onRoleTap),
        ],
      ),
    );
  }
}

/// Owner-only picker for switching a member between Editor (can edit
/// tasks and board settings) and Viewer (read-only, enforced by
/// security rules, not just hidden UI).
Future<String?> showRolePickerDialog(BuildContext context, String currentRole) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Change role'),
      children: [
        for (final r in const ['editor', 'viewer'])
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(r),
            child: Row(
              children: [
                Expanded(child: Text(r[0].toUpperCase() + r.substring(1))),
                if (r == currentRole) const Icon(Icons.check, size: 18, color: AppColors.primary),
              ],
            ),
          ),
      ],
    ),
  );
}
