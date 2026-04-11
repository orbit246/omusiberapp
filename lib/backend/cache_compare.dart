import 'dart:convert';

bool jsonPayloadEquals(Object? a, Object? b) {
  return jsonEncode(a) == jsonEncode(b);
}

bool jsonListEquals<T>(List<T> a, List<T> b, Object? Function(T item) toJson) {
  if (a.length != b.length) {
    return false;
  }

  for (var index = 0; index < a.length; index++) {
    if (!jsonPayloadEquals(toJson(a[index]), toJson(b[index]))) {
      return false;
    }
  }

  return true;
}
