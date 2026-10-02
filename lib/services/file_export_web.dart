import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [content] as [filename] via a
/// throwaway object-URL anchor click — the standard client-side-only
/// download pattern, since there's no backend here to serve the file
/// from.
bool downloadTextFile(String filename, String content) {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
  return true;
}
