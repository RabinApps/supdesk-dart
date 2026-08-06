/// Every error code the SupDesk API documents.
///
/// `limit_reached` and `rate_limited` share HTTP 429, which is why dispatch
/// happens on the code and only falls back to the status.
abstract final class SupDeskErrorCode {
  /// 400 — validation failed, bad JSON, or an invalid query parameter.
  static const String invalidRequest = 'invalid_request';

  /// 401 — missing, malformed, revoked, or unknown API key.
  static const String unauthorized = 'unauthorized';

  /// 403 — valid key, but the plan does not allow this action.
  static const String forbidden = 'forbidden';

  /// 404 — unknown route, or no such resource in this project.
  static const String notFound = 'not_found';

  /// 429 — the monthly submission quota is exhausted.
  static const String limitReached = 'limit_reached';

  /// 429 — too many requests in the current window.
  static const String rateLimited = 'rate_limited';

  /// 5xx — something failed on SupDesk's side.
  static const String internalError = 'internal_error';
}

/// Base class for everything this library throws.
///
/// Sealed, so a `switch` over a caught `SupDeskException` is exhaustive.
sealed class SupDeskException implements Exception {
  /// Creates an exception with a human-readable [message].
  const SupDeskException(this.message, {this.cause});

  /// A human-readable description of the failure.
  final String message;

  /// The underlying error, when this exception wraps one.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the client is constructed with unusable options.
final class SupDeskConfigurationException extends SupDeskException {
  /// Creates a configuration exception.
  const SupDeskConfigurationException(super.message);
}

/// The request never produced a response (DNS failure, socket reset, TLS
/// failure, …).
final class SupDeskConnectionException extends SupDeskException {
  /// Creates a connection exception.
  const SupDeskConnectionException([
    super.message = 'Could not reach the SupDesk API.',
    Object? cause,
  ]) : super(cause: cause);
}

/// The request exceeded the configured timeout.
final class SupDeskTimeoutException extends SupDeskException {
  /// Creates a timeout exception for a request that overran [timeout].
  SupDeskTimeoutException(this.timeout, {super.cause})
      : super('Request timed out after ${timeout.inMilliseconds}ms.');

  /// The deadline that was exceeded.
  final Duration timeout;
}

/// The serialized request body exceeds SupDesk's documented 1 MB cap.
///
/// Caught client-side so the failure names the real problem instead of arriving
/// as an opaque proxy error after the bytes have already gone over the wire.
final class RequestTooLargeException extends SupDeskException {
  /// Creates the exception for a body of [size] bytes against a [limit].
  RequestTooLargeException(this.size, this.limit)
      : super(
          'Request body is $size bytes, which exceeds the $limit byte API limit.',
        );

  /// Size of the serialized body, in bytes.
  final int size;

  /// The API's maximum request size, in bytes.
  final int limit;
}

/// A webhook payload did not match its signature.
final class SupDeskSignatureVerificationException extends SupDeskException {
  /// Creates a signature verification exception.
  const SupDeskSignatureVerificationException([
    super.message = 'Webhook signature verification failed.',
  ]);
}

/// The API responded, but with a non-2xx status.
class SupDeskApiException extends SupDeskException {
  /// Creates an API exception from a parsed error response.
  SupDeskApiException({
    required this.statusCode,
    required this.code,
    required String message,
    this.headers,
    this.body,
  }) : super(message);

  /// HTTP status code.
  final int statusCode;

  /// Machine-readable code from the response envelope, or `''` when the
  /// response carried no recognizable envelope.
  final String code;

  /// Response headers, lowercased by the transport.
  final Map<String, List<String>>? headers;

  /// Parsed response body, or the raw text when it was not JSON.
  final Object? body;

  /// Reads a response header, case-insensitively.
  String? header(String name) {
    final headers = this.headers;
    if (headers == null) return null;

    final wanted = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == wanted) {
        return entry.value.isEmpty ? null : entry.value.first;
      }
    }
    return null;
  }

  /// Opportunistic — SupDesk does not document a request-id header, but proxies
  /// in front of it often add one.
  String? get requestId =>
      header('x-request-id') ?? header('x-supdesk-request-id');

  @override
  String toString() => '$runtimeType($statusCode'
      '${code.isEmpty ? '' : ', $code'}): $message';
}

/// 400 — validation failed, bad JSON, or an invalid query parameter.
final class InvalidRequestException extends SupDeskApiException {
  /// Creates a 400 exception.
  InvalidRequestException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.headers,
    super.body,
  });
}

/// 401 — missing, malformed, revoked, or unknown API key.
final class UnauthorizedException extends SupDeskApiException {
  /// Creates a 401 exception.
  UnauthorizedException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.headers,
    super.body,
  });
}

/// 403 — valid key, but the plan does not allow this action.
///
/// Writes (`POST`, `PATCH`, `DELETE`) require a paid plan.
final class ForbiddenException extends SupDeskApiException {
  /// Creates a 403 exception.
  ForbiddenException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.headers,
    super.body,
  });
}

/// 404 — unknown route, or no such resource in this project.
final class NotFoundException extends SupDeskApiException {
  /// Creates a 404 exception.
  NotFoundException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.headers,
    super.body,
  });
}

/// 429 `rate_limited` — too many requests in the current window.
///
/// Retryable: the window will pass. SupDesk allows 120 requests per 60 seconds
/// per project.
final class RateLimitedException extends SupDeskApiException {
  /// Creates a 429 throttling exception.
  RateLimitedException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.headers,
    super.body,
  });
}

/// 429 `limit_reached` — the monthly submission quota is exhausted.
///
/// Deliberately *not* retryable: a monthly quota will not free up inside a
/// backoff window, so retrying only burns more of the caller's rate budget.
final class LimitReachedException extends SupDeskApiException {
  /// Creates a 429 quota exception.
  LimitReachedException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.headers,
    super.body,
  });
}

/// 5xx — something failed on SupDesk's side. Safe to retry.
final class InternalServerException extends SupDeskApiException {
  /// Creates a 5xx exception.
  InternalServerException({
    required super.statusCode,
    required super.code,
    required super.message,
    super.headers,
    super.body,
  });
}

/// Picks the most specific exception class for a response.
///
/// The documented code wins over the status because the two 429s mean very
/// different things; the status is only a fallback for undocumented responses
/// (a proxy 502, an HTML error page, …).
SupDeskApiException createApiException({
  required int statusCode,
  required String code,
  required String message,
  Map<String, List<String>>? headers,
  Object? body,
}) {
  switch (code) {
    case SupDeskErrorCode.invalidRequest:
      return InvalidRequestException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case SupDeskErrorCode.unauthorized:
      return UnauthorizedException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case SupDeskErrorCode.forbidden:
      return ForbiddenException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case SupDeskErrorCode.notFound:
      return NotFoundException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case SupDeskErrorCode.rateLimited:
      return RateLimitedException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case SupDeskErrorCode.limitReached:
      return LimitReachedException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case SupDeskErrorCode.internalError:
      return InternalServerException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
  }

  if (statusCode >= 500) {
    return InternalServerException(
      statusCode: statusCode,
      code: code,
      message: message,
      headers: headers,
      body: body,
    );
  }

  switch (statusCode) {
    case 400:
      return InvalidRequestException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case 401:
      return UnauthorizedException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case 403:
      return ForbiddenException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    case 404:
      return NotFoundException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    // An undocumented 429 shape is treated as throttling rather than quota:
    // retrying a throttle is harmless, whereas treating a throttle as a hard
    // quota failure would surface a spurious permanent error.
    case 429:
      return RateLimitedException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
    default:
      return SupDeskApiException(
        statusCode: statusCode,
        code: code,
        message: message,
        headers: headers,
        body: body,
      );
  }
}
