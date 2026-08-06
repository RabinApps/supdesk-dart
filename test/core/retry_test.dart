import 'package:supdesk/src/core/retry.dart' show sleepFor;
import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

SupDeskApiException apiError(int statusCode, [String code = '']) =>
    createApiException(
      statusCode: statusCode,
      code: code,
      message: 'boom',
    );

bool retries(
  Object error, {
  String method = 'GET',
  int attempt = 0,
  int maxRetries = 2,
  bool retryUnsafeMethods = false,
}) =>
    shouldRetry(
      error: error,
      method: method,
      attempt: attempt,
      maxRetries: maxRetries,
      retryUnsafeMethods: retryUnsafeMethods,
    );

void main() {
  group('shouldRetry', () {
    test('stops once the attempt budget is spent', () {
      expect(retries(apiError(500), attempt: 1), isTrue);
      expect(retries(apiError(500), attempt: 2), isFalse);
      expect(retries(apiError(500), maxRetries: 0), isFalse);
    });

    test('never retries limit_reached, even though it is a 429', () {
      final error = apiError(429, SupDeskErrorCode.limitReached);

      expect(error, isA<LimitReachedException>());
      expect(retries(error), isFalse);
      expect(retries(error, retryUnsafeMethods: true), isFalse);
    });

    test('retries rate_limited on any method', () {
      final error = apiError(429, SupDeskErrorCode.rateLimited);

      expect(retries(error, method: 'POST'), isTrue);
      expect(retries(error, method: 'GET'), isTrue);
    });

    test('does not replay POST on 5xx unless asked', () {
      expect(retries(apiError(500), method: 'POST'), isFalse);
      expect(
        retries(apiError(500), method: 'POST', retryUnsafeMethods: true),
        isTrue,
      );
    });

    test('replays every other method on 5xx and 408', () {
      for (final method in ['GET', 'head', 'DELETE', 'PATCH', 'PUT']) {
        expect(retries(apiError(503), method: method), isTrue, reason: method);
        expect(retries(apiError(408), method: method), isTrue, reason: method);
      }
    });

    test('does not retry other 4xx', () {
      expect(retries(apiError(400)), isFalse);
      expect(retries(apiError(401)), isFalse);
      expect(retries(apiError(403)), isFalse);
      expect(retries(apiError(404)), isFalse);
    });

    test('retries connection failures on safe methods only', () {
      const error = SupDeskConnectionException();

      expect(retries(error), isTrue);
      expect(retries(error, method: 'POST'), isFalse);
      expect(retries(error, method: 'POST', retryUnsafeMethods: true), isTrue);
    });

    test('surfaces timeouts instead of retrying them', () {
      expect(retries(SupDeskTimeoutException(const Duration(seconds: 1))),
          isFalse);
    });

    test('ignores errors it does not recognize', () {
      expect(retries(StateError('nope')), isFalse);
    });
  });

  group('parseRetryAfter', () {
    test('reads a delay in seconds', () {
      expect(parseRetryAfter('30'), const Duration(seconds: 30));
      expect(parseRetryAfter(' 1.5 '), const Duration(milliseconds: 1500));
      expect(parseRetryAfter('0'), Duration.zero);
    });

    test('reads an HTTP-date', () {
      final now = DateTime.utc(2015, 10, 21, 7, 28);

      expect(
        parseRetryAfter('Wed, 21 Oct 2015 07:28:30 GMT', now: now),
        const Duration(seconds: 30),
      );
    });

    test('clamps a date already in the past to zero', () {
      final now = DateTime.utc(2015, 10, 21, 8);

      expect(
        parseRetryAfter('Wed, 21 Oct 2015 07:28:00 GMT', now: now),
        Duration.zero,
      );
    });

    test('reads an ISO 8601 timestamp', () {
      final now = DateTime.utc(2026, 1, 1);

      expect(
        parseRetryAfter('2026-01-01T00:00:10Z', now: now),
        const Duration(seconds: 10),
      );
    });

    test('returns null for anything unusable', () {
      expect(parseRetryAfter(null), isNull);
      expect(parseRetryAfter(''), isNull);
      expect(parseRetryAfter('   '), isNull);
      expect(parseRetryAfter('soon'), isNull);
      expect(parseRetryAfter('Wed, 21 Foo 2015 07:28:00 GMT'), isNull);
    });
  });

  group('backoffDelay', () {
    test('doubles per attempt with jitter at its ceiling', () {
      expect(backoffDelay(attempt: 0, random: () => 1), baseRetryDelay);
      expect(
        backoffDelay(attempt: 1, random: () => 1),
        baseRetryDelay * 2,
      );
      expect(
        backoffDelay(attempt: 2, random: () => 1),
        baseRetryDelay * 4,
      );
    });

    test('halves the delay at the jitter floor', () {
      expect(
        backoffDelay(attempt: 0, random: () => 0),
        const Duration(milliseconds: 250),
      );
    });

    test('clamps the exponential growth', () {
      expect(backoffDelay(attempt: 10, random: () => 1), maxRetryDelay);
    });

    test('prefers a server-supplied Retry-After', () {
      expect(
        backoffDelay(
          attempt: 5,
          retryAfter: const Duration(seconds: 2),
          random: () => 1,
        ),
        const Duration(seconds: 2),
      );
    });

    test('clamps Retry-After too', () {
      expect(
        backoffDelay(attempt: 0, retryAfter: const Duration(minutes: 5)),
        maxRetryDelay,
      );
    });

    test('uses real randomness when none is injected', () {
      final delay = backoffDelay(attempt: 0);

      expect(delay, greaterThanOrEqualTo(const Duration(milliseconds: 250)));
      expect(delay, lessThanOrEqualTo(baseRetryDelay));
    });
  });

  test('sleepFor actually waits', () async {
    final stopwatch = Stopwatch()..start();
    await sleepFor(const Duration(milliseconds: 5));

    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(4));
  });
}
