/// No-op on non-web platforms (and the VM target `flutter test` runs on,
/// which can't compile the web-only `flutter_web_plugins` import at all).
void configureUrlStrategy() {}
