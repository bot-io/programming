/// Web implementation for JS interop helpers
/// Only compiled on web platforms via conditional import

import 'dart:js_interop';

/// Create a new JavaScript object
JSObject createJSObject() {
  return JSObject();
}

/// Set a property on a JavaScript object
void setJSProperty(JSObject obj, String key, dynamic value) {
  // On web, use jsify to convert and set via interop
  final jsValue = (value as Object).jsify() as JSAny;
  obj[key.toJS] = jsValue;
}
