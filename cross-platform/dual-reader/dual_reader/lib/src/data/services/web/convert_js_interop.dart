/// Helper class to create JavaScript objects from Dart
/// This works around Dart JS interop limitations

@JS('Object')
@staticInterop
class _JSObjectConstructor {
  external static JSObject create();
}

/// Create a new JavaScript object
JSObject createJSObject() {
  return _JSObjectConstructor.create();
}

/// Set a property on a JavaScript object
@JS('Object.defineProperty')
external void _defineProperty(JSObject obj, String key, JSObject descriptor);

/// Helper to set a property value on a JS object
void setJSProperty(JSObject obj, String key, dynamic value) {
  // Convert value to JS-compatible type
  final jsValue = _toJSValue(value);
  
  // Use bracket notation through interop
  (obj as JSObject)[key] = jsValue;
}

/// Convert Dart value to JS-compatible value
dynamic _toJSValue(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num) return value;
  if (value is bool) return value;
  if (value is JSObject) return value;
  return value.toString();
}
