import 'package:flutter/material.dart';
import '../models/member.dart';
import '../theme/app_text_styles.dart';

class MemberAvatar extends StatelessWidget {
  final Member member;
  final double size;
  final Color? ringColor;

  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 26,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: member.color,
        shape: BoxShape.circle,
        border: ringColor != null ? Border.all(color: ringColor!, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        member.initials,
        style: AppTextStyles.metaTiny(color: Colors.white).copyWith(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
