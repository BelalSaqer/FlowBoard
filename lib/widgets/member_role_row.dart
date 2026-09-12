import 'package:flutter/material.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'member_avatar.dart';

/// A member's role relative to a board — Owner is derived from the
/// board's `ownerId`; every other member shows as Editor since real
/// per-member roles aren't enforced yet (see board_settings_screen.dart).
class RoleBadge extends StatelessWidget {
  final bool isOwner;
  final VoidCallback? onTap;

  const RoleBadge({super.key, required this.isOwner, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              isOwner ? 'Owner' : 'Editor',
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
  final bool isOwner;
  final VoidCallback? onRoleTap;

  const MemberRoleRow({super.key, required this.member, required this.isOwner, this.onRoleTap});

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
          RoleBadge(isOwner: isOwner, onTap: onRoleTap),
        ],
      ),
    );
  }
}
