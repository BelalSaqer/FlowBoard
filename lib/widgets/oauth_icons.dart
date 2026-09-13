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

/// The Microsoft "four squares" mark, built from plain colored boxes —
/// instantly recognizable, no asset needed.
class MicrosoftIcon extends StatelessWidget {
  final double size;
  const MicrosoftIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final cell = (size - 2) / 2;
    Widget square(Color color) => Container(width: cell, height: cell, color: color);
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              square(const Color(0xFFF25022)),
              const SizedBox(width: 2),
              square(const Color(0xFF7FBA00)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              square(const Color(0xFF00A4EF)),
              const SizedBox(width: 2),
              square(const Color(0xFFFFB900)),
            ],
          ),
        ],
      ),
    );
  }
}
