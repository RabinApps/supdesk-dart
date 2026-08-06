/// Decoding helpers shared by every model.
///
/// They are deliberately forgiving: a field the API stops sending, or sends
/// with an unexpected type, should degrade to a sensible empty value rather
/// than throw halfway through parsing a page of results.
library;

/// Reads a string, falling back to `''`.
String stringOrEmpty(Object? value) => value is String ? value : '';

/// Reads a string, or `null` when absent or the wrong type.
String? stringOrNull(Object? value) => value is String ? value : null;

/// Reads an integer, falling back to `0`.
int intOrZero(Object? value) => value is num ? value.toInt() : 0;

/// Reads an integer, or `null` when absent or the wrong type.
int? intOrNull(Object? value) => value is num ? value.toInt() : null;

/// Reads a boolean, falling back to `false`.
bool boolOrFalse(Object? value) => value == true;

/// Parses an ISO 8601 timestamp, or `null` when absent or unparseable.
DateTime? dateTimeOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Reads a list of strings, dropping anything that is not one.
List<String> stringList(Object? value) => value is List
    ? List<String>.unmodifiable(value.whereType<String>())
    : const [];

/// Reads a nested JSON object, or `null`.
Map<String, dynamic>? objectOrNull(Object? value) =>
    value is Map<String, dynamic> ? value : null;

/// Reads a list of JSON objects, dropping anything that is not one.
List<Map<String, dynamic>> objectList(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

/// Element-wise list equality, for models whose `==` covers a list field.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Drops `null` entries, so an unset optional parameter is simply absent from
/// the request body rather than sent as an explicit `null`.
Map<String, Object?> pruneNulls(Map<String, Object?> json) => {
      for (final entry in json.entries)
        if (entry.value != null) entry.key: entry.value,
    };
