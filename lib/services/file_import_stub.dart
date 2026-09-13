/// Non-web platforms have no browser file-picker to open — returns null
/// so the caller can show "import is web-only" rather than hang.
Future<String?> pickTextFile({required String accept}) async => null;
