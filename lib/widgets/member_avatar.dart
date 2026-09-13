import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../providers/profile_provider.dart';
import '../theme/app_text_styles.dart';

/// Renders [member]'s live avatar photo (watched by uid, not embedded in
/// the [Member] snapshot itself) if one is set, falling back to the
/// initials-on-color circle otherwise. Live-watching by uid means a
/// photo you set on the profile screen shows up immediately everywhere
/// that member appears — task cards, comments, presence, invite lists —
/// without needing every place a [Member] is stored to carry image
/// bytes too.
class MemberAvatar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final photoB64 = ref.watch(memberPhotoProvider(member.id)).valueOrNull;
    Uint8List? bytes;
    if (photoB64 != null && photoB64.isNotEmpty) {
      try {
        bytes = base64Decode(photoB64);
      } catch (_) {
        bytes = null;
      }
    }

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Always keep the color fill, even when showing a photo: a photo
        // with any transparent pixels (a PNG with a transparent
        // background, a decode failure, a not-fully-loaded frame) would
        // otherwise show through as a see-through hole instead of a
        // reasonable-looking avatar.
        color: member.color,
        shape: BoxShape.circle,
        border: ringColor != null ? Border.all(color: ringColor!, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: bytes != null
          ? Image.memory(bytes, width: size, height: size, fit: BoxFit.cover)
          : Text(
              member.initials,
              style: AppTextStyles.metaTiny(color: Colors.white).copyWith(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
