import 'package:flutter/material.dart';
import '../models/priority.dart';
import '../theme/app_metrics.dart';
import '../theme/app_text_styles.dart';
import '../theme/priority_colors.dart';

class PriorityTag extends StatelessWidget {
  final Priority priority;
  const PriorityTag({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final colors = priorityColorsFor(priority, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        priority.label.toUpperCase(),
        style: AppTextStyles.badge(color: colors.text).copyWith(fontSize: 10),
      ),
    );
  }
}
