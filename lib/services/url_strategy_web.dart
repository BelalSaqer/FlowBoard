import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Plain `/join/{boardId}` URLs instead of `/#/join/{boardId}` — makes
/// for a shareable invite link that doesn't look broken.
void configureUrlStrategy() {
  usePathUrlStrategy();
}
