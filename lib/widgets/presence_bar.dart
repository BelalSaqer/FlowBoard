import 'package:flutter/material.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import 'member_avatar.dart';

/// Live-viewing indicator: first 3 avatars + "+N" badge, matching the
/// design's presence bar pattern.
class PresenceBar extends StatelessWidget {
  final List<Member> viewers;
  const PresenceBar({super.key, required this.viewers});

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final shown = viewers.take(3).toList();
    final extra = viewers.length - shown.length;
    final label = viewers.length > 3
        ? '${viewers[0].name}, ${viewers[1].name} and ${viewers.length - 2} others viewing'
        : '${viewers.map((v) => v.name).join(', ')} viewing';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          SizedBox(
            width: shown.length * 19.0 + 7,
            height: 26,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * 19.0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        MemberAvatar(member: shown[i], ringColor: surface),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: surface, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (extra > 0)
                  Positioned(
                    left: shown.length * 19.0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        shape: BoxShape.circle,
                        border: Border.all(color: surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+$extra',
                        style: AppTextStyles.metaTiny(
                          color: AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppRadii.liveBadge),
            ),
            child: Text(
              'LIVE',
              style: AppTextStyles.metaSmall(
                color: AppColors.primary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
