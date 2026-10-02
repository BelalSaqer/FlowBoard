import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens the browser's native file picker restricted to [accept] (e.g.
/// `.csv`) and resolves to the chosen file's text content, or null if the
/// dialog was cancelled. Mirrors the photo-upload lesson from profile
/// photos: `.click()` fires as the very first statement here, with no
/// `await` before it, so this must itself be called with no `await` gap
/// from the original tap — otherwise the browser won't treat the picker
/// as a genuine user gesture and it silently won't open.
Future<String?> pickTextFile({required String accept}) {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.click();

  void resolveNull() {
    if (!completer.isCompleted) completer.complete(null);
  }

  bool hasNoFile() {
    final files = input.files;
    return files == null || files.length == 0;
  }

  web.EventStreamProviders.changeEvent.forTarget(input).listen((_) {
    final file = input.files?.item(0);
    if (file == null) {
      resolveNull();
      return;
    }
    final reader = web.FileReader();
    web.EventStreamProviders.loadEndEvent.forTarget(reader).listen((_) {
      if (completer.isCompleted) return;
      final result = reader.result;
      completer.complete(
        result != null && result.isA<JSString>()
            ? (result as JSString).toDart
            : null,
      );
    });
    web.EventStreamProviders.errorEvent
        .forTarget(reader)
        .listen((_) => resolveNull());
    reader.readAsText(file);
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
  const web.EventStreamProvider<web.Event>('cancel')
      .forTarget(input)
      .listen((_) => resolveNull());
  late final StreamSubscription<web.Event> focusSub;
  focusSub =
      web.EventStreamProviders.focusEvent.forTarget(web.window).listen((_) {
    focusSub.cancel();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted && hasNoFile()) resolveNull();
    });
  });

  return completer.future;
}
