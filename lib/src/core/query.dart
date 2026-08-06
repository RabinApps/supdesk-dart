/// Serializes query parameters, dropping `null`.
///
/// `null` means "the caller did not set this" and is omitted; `false` and `0`
/// are meaningful values and are kept. [Iterable] values are repeated
/// (`?labels=a&labels=b`).
///
/// Returns `''` when there is nothing to append, so callers can concatenate
/// unconditionally.
String buildQueryString(Map<String, Object?>? params) {
  if (params == null || params.isEmpty) return '';

  final pairs = <String>[];

  for (final entry in params.entries) {
    final value = entry.value;
    if (value == null) continue;

    final key = Uri.encodeQueryComponent(entry.key);

    if (value is Iterable) {
      for (final item in value) {
        pairs.add('$key=${Uri.encodeQueryComponent(item.toString())}');
      }
      continue;
    }

    pairs.add('$key=${Uri.encodeQueryComponent(value.toString())}');
  }

  return pairs.isEmpty ? '' : '?${pairs.join('&')}';
}

/// Joins a base URL and a path with exactly one slash between them, so both
/// `https://api.supdesk.app/v1` and `https://api.supdesk.app/v1/` behave the
/// same.
String joinUrl(String baseUrl, String path) {
  final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final suffix = path.replaceAll(RegExp(r'^/+'), '');
  return '$base/$suffix';
}

/// Percent-encodes a path segment.
///
/// Ids come from the caller, so an id containing `/` or `?` must not be able to
/// escape its segment and rewrite the route.
String encodePathSegment(Object segment) =>
    Uri.encodeComponent(segment.toString());
