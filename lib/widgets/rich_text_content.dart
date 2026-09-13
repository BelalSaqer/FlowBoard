import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/rich_text_tokens.dart';
import '../theme/app_colors.dart';

/// Renders plain text with a minimal, intentionally non-extensible set of
/// inline markers (see [parseRichText] for the exact grammar): `@mention`
/// (highlighted, not resolved — resolving who it actually notifies
/// happens server-side in BoardTasksNotifier.addComment), **bold**,
/// *italic*, `code`, and [text](url) links (tappable, opened in a new
/// tab). No editor/toolbar — you type the markers directly, same as a
/// comment field on GitHub or Slack.
class RichTextContent extends StatelessWidget {
  final String text;
  final TextStyle style;
  const RichTextContent({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[
      for (final token in parseRichText(text)) _spanFor(token),
    ];
    return RichText(text: TextSpan(style: style, children: spans));
  }

  InlineSpan _spanFor(RichToken token) {
    switch (token.type) {
      case RichTokenType.plain:
        return TextSpan(text: token.text);
      case RichTokenType.mention:
        return TextSpan(text: token.text, style: style.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700));
      case RichTokenType.bold:
        return TextSpan(text: token.text, style: style.copyWith(fontWeight: FontWeight.w800));
      case RichTokenType.italic:
        return TextSpan(text: token.text, style: style.copyWith(fontStyle: FontStyle.italic));
      case RichTokenType.code:
        return TextSpan(
          text: token.text,
          style: style.copyWith(fontFamily: 'monospace', backgroundColor: AppColors.primaryTintSoft),
        );
      case RichTokenType.link:
        return TextSpan(
          text: token.text,
          style: style.copyWith(color: AppColors.primary, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final uri = Uri.tryParse(token.url ?? '');
              if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
        );
    }
  }
}
