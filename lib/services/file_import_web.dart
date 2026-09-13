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

  void resolveNull() {
    if (!completer.isCompleted) completer.complete(null);
  }

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      resolveNull();
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) completer.complete(reader.result as String?);
    });
    reader.onError.listen((_) => resolveNull());
    reader.readAsText(files.first);
  });

  // Neither 'change' nor a dedicated cancel event is guaranteed to fire
  // in every browser when the dialog is dismissed with no file chosen —
  // without a fallback, the Future (and whatever awaits it, e.g.
  // _importCsv) would hang forever. The native 'cancel' event (decent
  // modern-browser support) resolves this directly; as a backstop for
  // browsers without it, the *window* regaining focus is the OS-level
  // signal that the dialog just closed one way or another, so a short
  // grace period after that — long enough for a real 'change' event to
  // land first if a file actually was chosen — treats a still-empty file
  // list as a cancel too.
  input.on['cancel'].listen((_) => resolveNull());
  late final StreamSubscription<html.Event> focusSub;
  focusSub = html.window.onFocus.listen((_) {
    focusSub.cancel();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted && (input.files == null || input.files!.isEmpty)) {
        resolveNull();
      }
    });
  });

  return completer.future;
}
