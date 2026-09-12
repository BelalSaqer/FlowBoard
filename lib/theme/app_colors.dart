import 'package:flutter/material.dart';

/// FlowBoard color tokens — ported from the Claude Design export.
class AppColors {
  AppColors._();

  // Primary (deep violet)
  static const primary = Color(0xFF5B45E0);
  static const primaryLight = Color(0xFF8E79FF); // hover/accent state
  static const primaryTint = Color(0xFFECE8FD); // badges, selected states
  static const primaryTintSoft = Color(0xFFF0EEF8);

  // Text — light mode
  static const textPrimaryLight = Color(0xFF171527);
  static const textSecondaryLight = Color(0xFF56526B);
  static const textMutedLight = Color(0xFF6C6880);
  static const textFaintLight = Color(0xFF8C88A8);
  static const textDisabledLight = Color(0xFFAEAABF);

  // Text — dark mode
  static const textPrimaryDark = Color(0xFFF3F2F8);
  static const textSecondaryDark = Color(0xFFC9C6D6);
  static const textMutedDark = Color(0xFFAEAABF);

  // Backgrounds — light mode
  static const bgLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFF6F5FA);
  static const surfaceAltLight = Color(0xFFF3F2F8);
  static const borderLight = Color(0x1A171527);

  // Backgrounds — dark mode
  static const bgDark = Color(0xFF0E0D14);
  static const surfaceDark = Color(0xFF191821);
  static const surfaceAltDark = Color(0xFF201F2A);
  static const cardDark = Color(0xFF262046);
  static const borderDark = Color(0x1AFFFFFF);

  // Priority — Low (sage green)
  static const priorityLow = Color(0xFF2F9E8F);
  static const priorityLowAlt = Color(0xFF3B9E77);
  static const priorityLowBg = Color(0xFFE4F0E9);
  static const priorityLowText = Color(0xFF3B7659);
  static const priorityLowBgDark = Color(0x2D6FA88A);
  static const priorityLowTextDark = Color(0xFF8FC9AB);

  // Priority — Medium (amber)
  static const priorityMedium = Color(0xFFD98B12);
  static const priorityMediumAlt = Color(0xFFE9BB5C);
  static const priorityMediumBg = Color(0xFFFBF0DA);
  static const priorityMediumText = Color(0xFF96690A);
  static const priorityMediumBgDark = Color(0x2DE3A008);
  static const priorityMediumTextDark = Color(0xFFE9BB5C);

  // Priority — High (coral/red)
  static const priorityHigh = Color(0xFFE8613C);
  static const priorityHighAlt = Color(0xFFEC7A57);
  static const priorityHighBg = Color(0xFFFCE7DE);
  static const priorityHighText = Color(0xFFB14A22);
  static const priorityHighBgDark = Color(0x2DE8613C);
  static const priorityHighTextDark = Color(0xFFF2A184);

  // Success / live indicator
  static const success = Color(0xFF34C77B);
  static const successSoft = Color(0xFF8FC9AB);

  // Misc accents seen in avatars/tags
  static const accentPink = Color(0xFFC2437F);
  static const accentOrange = Color(0xFFF2A184);
  static const accentAmberDeep = Color(0xFFDEA33C);

  static const List<Color> avatarPalette = [
    primary,
    priorityHigh,
    priorityLow,
    priorityMedium,
    accentPink,
  ];
}
