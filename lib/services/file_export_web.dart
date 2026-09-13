import 'dart:convert';
import 'dart:html' as html;

/// Triggers a browser download of [content] as [filename] via a
/// throwaway object-URL anchor click — the standard client-side-only
/// download pattern, since there's no backend here to serve the file
/// from.
bool downloadTextFile(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
