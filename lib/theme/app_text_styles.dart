import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FlowBoard type scale.
/// UI text uses Plus Jakarta Sans; numbers/timestamps/meta use IBM Plex Mono.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _ui({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color,
  );

  static TextStyle _mono({
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    Color? color,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color,
  );

  // Headings (UI font)
  static TextStyle h1({Color? color}) =>
      _ui(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: color);
  static TextStyle h2({Color? color}) =>
      _ui(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: color);
  static TextStyle h3({Color? color}) =>
      _ui(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: color);

  // Body (UI font)
  static TextStyle bodyLarge({Color? color}) =>
      _ui(fontSize: 15.5, fontWeight: FontWeight.w500, color: color);
  static TextStyle body({Color? color}) =>
      _ui(fontSize: 13.5, fontWeight: FontWeight.w400, color: color);
  static TextStyle bodySmall({Color? color}) =>
      _ui(fontSize: 12.5, fontWeight: FontWeight.w400, color: color);
  static TextStyle bodySemibold({Color? color}) =>
      _ui(fontSize: 13.5, fontWeight: FontWeight.w600, color: color);

  // Meta/mono (timestamps, counts, priority labels)
  static TextStyle metaMedium({Color? color}) =>
      _mono(fontSize: 12, fontWeight: FontWeight.w500, color: color);
  static TextStyle meta({Color? color}) =>
      _mono(fontSize: 11, fontWeight: FontWeight.w500, color: color);
  static TextStyle metaSmall({Color? color}) =>
      _mono(fontSize: 10.5, fontWeight: FontWeight.w500, color: color);
  static TextStyle metaTiny({Color? color}) =>
      _mono(fontSize: 9.5, fontWeight: FontWeight.w500, color: color);
  static TextStyle badge({Color? color}) => _mono(
    fontSize: 8,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: color,
  );
}
