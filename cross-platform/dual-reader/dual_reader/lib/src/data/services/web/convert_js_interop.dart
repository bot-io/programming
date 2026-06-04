/// Helper class to create JavaScript objects from Dart
/// Stub that exports nothing functional on non-web platforms
/// The web implementation is in convert_js_interop_web.dart

/// Create a new JavaScript object (stub - returns null on non-web)
dynamic createJSObject() => throw UnsupportedError('JS interop only available on web');

/// Set a property on a JavaScript object (stub - no-op on non-web)
void setJSProperty(dynamic obj, String key, dynamic value) {
  throw UnsupportedError('JS interop only available on web');
}
