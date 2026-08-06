import 'dart:math' as math;

import 'errors.dart';

/// Retries attempted after the first request, by default.
const int defaultMaxRetries = 2;

/// First backoff step; doubles per attempt.
const Duration baseRetryDelay = Duration(milliseconds: 500);

/// Ceiling for any computed or server-supplied backoff.
const Duration maxRetryDelay = Duration(seconds: 8);

/// HTTP methods that are safe to replay without risking a duplicate write.
const Set<String> _safeMethods = {
  'GET',
  'HEAD',
  'DELETE',
  'PATCH',
  'PUT',
  'OPTIONS',
};

/// Decides whether a failed attempt is worth repeating.
///
/// Two rules carry most of the weight:
///
/// 1. A 429 `limit_reached` is never retried. It means the monthly submission
///    quota is gone, which no amount of backoff will fix.
/// 2. A failed `POST` is not replayed on a connection error or 5xx unless the
///    caller opts in via [retryUnsafeMethods]. SupDesk documents no idempotency
///    key, and both `POST /submissions` and `POST /feedback` are metered against
///    the monthly quota — a request that failed *after* the server accepted it
///    would be double-charged and would file the end user's ticket twice. A 429
///    `rate_limited` is different: the server is explicitly saying it did not
///    process the request, so replaying it is safe for any method.
bool shouldRetry({
  required Object error,
  required String method,
  required int attempt,
  required int maxRetries,
  required bool retryUnsafeMethods,
}) {
  if (attempt >= maxRetries) return false;

  final methodIsSafe =
      _safeMethods.contains(method.toUpperCase()) || retryUnsafeMethods;

  if (error is LimitReachedException) return false;

  if (error is SupDeskApiException) {
    // The server rejected the request outright — safe to replay regardless.
    if (error.statusCode == 429) return true;
    if (error.statusCode == 408) return methodIsSafe;
    if (error.statusCode >= 500) return methodIsSafe;
    return false;
  }

  if (error is SupDeskConnectionException) return methodIsSafe;

  // Timeouts are surfaced, not retried: the caller chose the deadline, and
  // silently spending it several times over defeats the point.
  return false;
}

/// Parses a `Retry-After` header, which may be either a delay in seconds or an
/// HTTP-date.
///
/// SupDesk does not document sending one, but honouring it costs nothing and
/// behaves correctly behind a proxy or CDN that does. Returns `null` for
/// anything unparseable or nonsensical.
Duration? parseRetryAfter(String? header, {DateTime? now}) {
  if (header == null) return null;

  final trimmed = header.trim();
  if (trimmed.isEmpty) return null;

  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(trimmed)) {
    final seconds = double.parse(trimmed);
    return Duration(milliseconds: math.max(0, (seconds * 1000).round()));
  }

  final date = _parseHttpDate(trimmed);
  if (date == null) return null;

  final delta = date.difference(now ?? DateTime.now());
  return delta.isNegative ? Duration.zero : delta;
}

const List<String> _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

final RegExp _imfFixdate = RegExp(
  r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
  r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
);

/// Parses an IMF-fixdate (`Wed, 21 Oct 2015 07:28:00 GMT`) or an ISO-8601
/// timestamp.
///
/// Hand-rolled rather than using `dart:io`'s `HttpDate`, so the package stays
/// free of `dart:io` and works unchanged wherever dio does.
DateTime? _parseHttpDate(String value) {
  final match = _imfFixdate.firstMatch(value);
  if (match != null) {
    final month = _months.indexOf(match.group(2)!.toLowerCase());
    if (month == -1) return null;

    return DateTime.utc(
      int.parse(match.group(3)!),
      month + 1,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }

  return DateTime.tryParse(value);
}

/// Exponential backoff with jitter, clamped to [maxRetryDelay].
///
/// Jitter spreads retries out so that a fleet of workers rate-limited at the
/// same instant does not stampede the API in lockstep when the window opens. A
/// server-supplied [retryAfter] wins over the computed delay.
Duration backoffDelay({
  required int attempt,
  Duration? retryAfter,
  double Function()? random,
}) {
  if (retryAfter != null) {
    return retryAfter > maxRetryDelay ? maxRetryDelay : retryAfter;
  }

  final exponential = math.min(
    baseRetryDelay.inMilliseconds * math.pow(2, attempt).toInt(),
    maxRetryDelay.inMilliseconds,
  );
  final jitter = 0.5 + (random ?? math.Random().nextDouble)() / 2;

  return Duration(milliseconds: (exponential * jitter).round());
}

/// Default sleep. Injected in tests so retry suites do not spend real time.
Future<void> sleepFor(Duration duration) => Future<void>.delayed(duration);
