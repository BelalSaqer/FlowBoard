import 'package:flutter/material.dart';

/// The circular "back" icon button used at the top of every pushed
/// screen. Wrapped in [Tooltip] rather than a bare [Icon] — that's what
/// gives it both a hover label on desktop/web and, just as importantly, a
/// semantic label a screen reader announces; an icon-only [InkWell] with
/// no text has nothing for assistive tech to read otherwise.
class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const AppBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.arrow_back_ios_new, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}
