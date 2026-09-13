enum RichTokenType { plain, mention, bold, italic, code, link }

class RichToken {
  final RichTokenType type;
  final String text;
  final String? url;
  const RichToken({required this.type, required this.text, this.url});

  @override
  bool operator ==(Object other) =>
      other is RichToken && other.type == type && other.text == text && other.url == url;

  @override
  int get hashCode => Object.hash(type, text, url);

  @override
  String toString() => 'RichToken($type, "$text"${url != null ? ', $url' : ''})';
}

final _tokenPattern = RegExp(
  r'((?<![a-zA-Z0-9])@[a-z0-9_]{3,20})' // @mention — not inside an email address
  r'|(\*\*[^*\n]+\*\*)' // **bold**
  r'|(\*[^*\n]+\*)' // *italic*
  r'|(`[^`\n]+`)' // `code`
  r'|(\[[^\]\n]+\]\([^\)\n]+\))', // [text](url)
  caseSensitive: false,
);

final _linkPattern = RegExp(r'^\[([^\]]+)\]\(([^\)]+)\)$');

/// Splits [text] into plain runs and a minimal, intentionally non-
/// extensible set of inline markers: `@mention`, **bold**, *italic*,
/// `code`, and [text](url). Pure function so the parsing logic can be
/// tested without pumping a widget — [RichTextContent] just maps these
/// tokens to [TextSpan]s.
List<RichToken> parseRichText(String text) {
  final tokens = <RichToken>[];
  var last = 0;
  for (final match in _tokenPattern.allMatches(text)) {
    if (match.start > last) {
      tokens.add(RichToken(type: RichTokenType.plain, text: text.substring(last, match.start)));
    }
    final raw = match.group(0)!;
    if (match.group(1) != null) {
      tokens.add(RichToken(type: RichTokenType.mention, text: raw));
    } else if (match.group(2) != null) {
      tokens.add(RichToken(type: RichTokenType.bold, text: raw.substring(2, raw.length - 2)));
    } else if (match.group(3) != null) {
      tokens.add(RichToken(type: RichTokenType.italic, text: raw.substring(1, raw.length - 1)));
    } else if (match.group(4) != null) {
      tokens.add(RichToken(type: RichTokenType.code, text: raw.substring(1, raw.length - 1)));
    } else if (match.group(5) != null) {
      final linkMatch = _linkPattern.firstMatch(raw)!;
      tokens.add(RichToken(type: RichTokenType.link, text: linkMatch.group(1)!, url: linkMatch.group(2)));
    }
    last = match.end;
  }
  if (last < text.length) {
    tokens.add(RichToken(type: RichTokenType.plain, text: text.substring(last)));
  }
  return tokens;
}
