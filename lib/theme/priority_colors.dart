import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../models/priority.dart';

/// Resolves the (accent, background, text) triad for a priority level,
/// matching the 2px left-rule + pill tag pattern from the design.
class PriorityColorSet {
  final Color accent;
  final Color background;
  final Color text;
  const PriorityColorSet(this.accent, this.background, this.text);
}

PriorityColorSet priorityColorsFor(Priority priority, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  switch (priority) {
    case Priority.low:
      return isDark
          ? const PriorityColorSet(
              AppColors.priorityLowAlt,
              AppColors.priorityLowBgDark,
              AppColors.priorityLowTextDark,
            )
          : const PriorityColorSet(
              AppColors.priorityLow,
              AppColors.priorityLowBg,
              AppColors.priorityLowText,
            );
    case Priority.medium:
      return isDark
          ? const PriorityColorSet(
              AppColors.priorityMediumAlt,
              AppColors.priorityMediumBgDark,
              AppColors.priorityMediumTextDark,
            )
          : const PriorityColorSet(
              AppColors.priorityMedium,
              AppColors.priorityMediumBg,
              AppColors.priorityMediumText,
            );
    case Priority.high:
      return isDark
          ? const PriorityColorSet(
              AppColors.priorityHighAlt,
              AppColors.priorityHighBgDark,
              AppColors.priorityHighTextDark,
            )
          : const PriorityColorSet(
              AppColors.priorityHigh,
              AppColors.priorityHighBg,
              AppColors.priorityHighText,
            );
  }
}
