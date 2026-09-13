import 'package:flutter/material.dart';

/// Simplified Google "G" mark — a white circle with the letter in
/// Google's blue. Not the full multi-color logo (that needs an actual
/// asset/SVG), but reads clearly as "Google" next to the button text.
class GoogleIcon extends StatelessWidget {
  final double size;
  const GoogleIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: TextStyle(
          fontSize: size * 0.62,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF4285F4),
          height: 1,
        ),
      ),
    );
  }
}

/// The Apple mark, via Flutter's built-in Material icon glyph — no
/// asset needed, color passed in so it can be white-on-black (the
/// standard "Sign in with Apple" button style) or any other context.
class AppleIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AppleIcon({super.key, this.size = 18, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.apple, size: size, color: color);
  }
}
