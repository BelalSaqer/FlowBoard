import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// App-lifetime navigator/messenger keys, so the join-link handler (which
/// fires from a provider callback, not a stable widget) can navigate and
/// show errors without depending on any particular widget's BuildContext
/// surviving the async round-trip to Firestore.
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

String? _initialJoinBoardId;
bool _captured = false;

/// Must be called exactly once, as the very first thing in main() —
/// before WidgetsFlutterBinding or anything else runs. Dart's top-level
/// variables are lazily initialized on first read, and by the time
/// something deep in the widget tree first asked for this (originally:
/// on first build of the post-sign-in screen), Flutter's own web
/// navigation integration had already normalized the address bar back
/// to "/", silently losing the `/join/{boardId}` path. Reading
/// `Uri.base` this early, before any of that has a chance to run, is
/// what actually captures the link the app was opened with.
void captureInitialDeepLink() {
  if (_captured) return;
  _captured = true;
  if (!kIsWeb) return;
  try {
    final segments = Uri.base.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length == 2 && segments[0] == 'join') {
      _initialJoinBoardId = segments[1];
    }
  } catch (e) {
    debugPrint('captureInitialDeepLink: failed to parse Uri.base: $e');
  }
}

/// Reads and clears the pending join board id, so it's only ever acted
/// on once even if the widget that consumes it rebuilds.
String? takeInitialJoinBoardId() {
  final id = _initialJoinBoardId;
  _initialJoinBoardId = null;
  return id;
}
