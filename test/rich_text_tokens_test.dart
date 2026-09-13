import 'package:flutter_test/flutter_test.dart';
import 'package:flowboard/data/rich_text_tokens.dart';

void main() {
  test('plain text with no markers is a single plain token', () {
    final tokens = parseRichText('just plain text');
    expect(tokens, [const RichToken(type: RichTokenType.plain, text: 'just plain text')]);
  });

  test('parses bold, italic, code, mention, and a link, preserving surrounding plain text', () {
    final tokens = parseRichText('hey @bob check **this** and *that* — `fix()` — [docs](https://example.com)');
    expect(tokens, [
      const RichToken(type: RichTokenType.plain, text: 'hey '),
      const RichToken(type: RichTokenType.mention, text: '@bob'),
      const RichToken(type: RichTokenType.plain, text: ' check '),
      const RichToken(type: RichTokenType.bold, text: 'this'),
      const RichToken(type: RichTokenType.plain, text: ' and '),
      const RichToken(type: RichTokenType.italic, text: 'that'),
      const RichToken(type: RichTokenType.plain, text: ' — '),
      const RichToken(type: RichTokenType.code, text: 'fix()'),
      const RichToken(type: RichTokenType.plain, text: ' — '),
      const RichToken(type: RichTokenType.link, text: 'docs', url: 'https://example.com'),
    ]);
  });

  test('an empty string produces no tokens', () {
    expect(parseRichText(''), isEmpty);
  });

  test('unmatched single asterisk is left as plain text, not treated as italic', () {
    final tokens = parseRichText('5 * 3 = 15');
    expect(tokens, [const RichToken(type: RichTokenType.plain, text: '5 * 3 = 15')]);
  });

  test('an email address is not parsed as a mention', () {
    final tokens = parseRichText('reach me at ahmed@company.com for details');
    expect(tokens, [
      const RichToken(type: RichTokenType.plain, text: 'reach me at ahmed@company.com for details'),
    ]);
  });

  test('a real mention right after an email address still resolves', () {
    final tokens = parseRichText('ahmed@company.com cc @bob');
    expect(tokens, [
      const RichToken(type: RichTokenType.plain, text: 'ahmed@company.com cc '),
      const RichToken(type: RichTokenType.mention, text: '@bob'),
    ]);
  });

  test('a mention at the very start of the text still resolves', () {
    final tokens = parseRichText('@bob take a look');
    expect(tokens, [
      const RichToken(type: RichTokenType.mention, text: '@bob'),
      const RichToken(type: RichTokenType.plain, text: ' take a look'),
    ]);
  });
}
