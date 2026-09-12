import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The FlowBoard mark — three vertical bars (short, tall, medium) on a
/// rounded-square background, matching the brand icon. Built as vectors
/// (not an image asset) so it scales cleanly and stays consistent with
/// the rest of the app's non-image visual style.
class FlowBoardLogo extends StatelessWidget {
  final double size;
  final bool showBackground;
  final Color? backgroundColor;
  final Color? barColor;

  const FlowBoardLogo({
    super.key,
    this.size = 64,
    this.showBackground = true,
    this.backgroundColor,
    this.barColor,
  });

  static const _heights = [0.42, 0.82, 0.60];

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primary;
    final bars = barColor ?? Colors.white;
    final corner = size * 0.22;
    final pad = size * 0.24;
    final innerW = size - 2 * pad;
    final gap = innerW * 0.14;
    final barW = (innerW - 2 * gap) / 3;
    final availH = size - 2 * pad;

    return Container(
      width: size,
      height: size,
      decoration: showBackground
          ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(corner))
          : null,
      padding: EdgeInsets.all(pad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            if (i != 0) SizedBox(width: gap),
            Container(
              width: barW,
              height: availH * _heights[i],
              decoration: BoxDecoration(
                color: bars,
                borderRadius: BorderRadius.circular(barW * 0.35),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal "icon + wordmark" lockup, e.g. for a compact app-bar brand.
class FlowBoardWordmark extends StatelessWidget {
  final double iconSize;
  final Color? textColor;

  const FlowBoardWordmark({super.key, this.iconSize = 28, this.textColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlowBoardLogo(size: iconSize, showBackground: false, barColor: AppColors.primary),
        SizedBox(width: iconSize * 0.32),
        Text(
          'FlowBoard',
          style: TextStyle(
            fontSize: iconSize * 0.75,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: textColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
