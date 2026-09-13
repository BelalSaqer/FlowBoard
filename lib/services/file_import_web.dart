import 'dart:async';
import 'dart:html' as html;

/// Opens the browser's native file picker restricted to [accept] (e.g.
/// `.csv`) and resolves to the chosen file's text content, or null if the
/// dialog was cancelled. Mirrors the photo-upload lesson from profile
/// photos: `.click()` fires as the very first statement here, with no
/// `await` before it, so this must itself be called with no `await` gap
/// from the original tap — otherwise the browser won't treat the picker
/// as a genuine user gesture and it silently won't open.
Future<String?> pickTextFile({required String accept}) {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = accept;
  input.click();
  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      completer.complete(reader.result as String?);
    });
    reader.onError.listen((_) => completer.complete(null));
    reader.readAsText(files.first);
  });
  return completer.future;
}
