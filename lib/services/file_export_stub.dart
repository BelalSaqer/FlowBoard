/// Non-web platforms (and the VM target `flutter test` runs on) have no
/// browser download mechanism to trigger — the caller checks the return
/// value and shows "export is web-only" rather than silently failing.
bool downloadTextFile(String filename, String content) => false;
