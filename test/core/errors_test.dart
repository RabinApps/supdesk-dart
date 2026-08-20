import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

SupDeskApiException build({
  int statusCode = 400,
  String code = '',
  String message = 'boom',
  Map<String, List<String>>? headers,
  Object? body,
}) =>
    createApiException(
      statusCode: statusCode,
      code: code,
      message: message,
      headers: headers,
      body: body,
    );

void main() {
  group('createApiException dispatches on code', () {
    final cases = <String, Type>{
      SupDeskErrorCode.invalidRequest: InvalidRequestException,
      SupDeskErrorCode.unauthorized: UnauthorizedException,
      SupDeskErrorCode.notFound: NotFoundException,
      SupDeskErrorCode.rateLimited: RateLimitedException,
      SupDeskErrorCode.limitReached: LimitReachedException,
      SupDeskErrorCode.internalError: InternalServerException,
    };

    cases.forEach((code, type) {
      test('$code -> $type', () {
        // Status deliberately mismatched: the code has to win.
        expect(build(statusCode: 418, code: code).runtimeType, type);
      });
    });

    test('tells the two 429s apart by code alone', () {
      expect(
        build(statusCode: 429, code: SupDeskErrorCode.rateLimited),
        isA<RateLimitedException>(),
      );
      expect(
        build(statusCode: 429, code: SupDeskErrorCode.limitReached),
        isA<LimitReachedException>(),
      );
    });
  });

  group('createApiException falls back to status', () {
    test('maps documented statuses', () {
      expect(build(statusCode: 400), isA<InvalidRequestException>());
      expect(build(statusCode: 401), isA<UnauthorizedException>());
      expect(build(statusCode: 404), isA<NotFoundException>());
    });

    test('leaves a 403 as the base class', () {
      // SupDesk removed `forbidden` when write access reached every plan, so a
      // 403 now only arrives from something in front of the API — a proxy, a
      // WAF — and is given no meaning the API does not define.
      final error = build(statusCode: 403);

      expect(error.runtimeType, SupDeskApiException);
      expect(error.statusCode, 403);
    });

    test('treats an undocumented 429 as throttling, not quota', () {
      final error = build(statusCode: 429);

      expect(error, isA<RateLimitedException>());
      expect(error, isNot(isA<LimitReachedException>()));
    });

    test('maps every 5xx to InternalServerException', () {
      expect(build(statusCode: 500), isA<InternalServerException>());
      expect(build(statusCode: 502), isA<InternalServerException>());
      expect(build(statusCode: 599), isA<InternalServerException>());
    });

    test('leaves anything else as the base class', () {
      final error = build(statusCode: 418);

      expect(error.runtimeType, SupDeskApiException);
      expect(error.statusCode, 418);
    });
  });

  group('SupDeskApiException', () {
    test('reads headers case-insensitively', () {
      final error = build(
        headers: {
          'Retry-After': ['30'],
        },
      );

      expect(error.header('retry-after'), '30');
      expect(error.header('RETRY-AFTER'), '30');
      expect(error.header('missing'), isNull);
    });

    test('returns null for an empty header value list', () {
      final error = build(headers: {'x-request-id': []});

      expect(error.header('x-request-id'), isNull);
      expect(error.requestId, isNull);
    });

    test('returns null for headers when none were captured', () {
      expect(build().header('anything'), isNull);
    });

    test('picks up either request id header', () {
      expect(
        build(
          headers: {
            'x-request-id': ['abc'],
          },
        ).requestId,
        'abc',
      );
      expect(
        build(
          headers: {
            'x-supdesk-request-id': ['def'],
          },
        ).requestId,
        'def',
      );
    });

    test('carries the parsed body', () {
      final error = build(body: {'error': 'nope'});

      expect(error.body, {'error': 'nope'});
    });

    test('toString names the status and code', () {
      expect(
        build(statusCode: 404, code: 'not_found', message: 'gone').toString(),
        'NotFoundException(404, not_found): gone',
      );
      expect(
          build(statusCode: 418).toString(), 'SupDeskApiException(418): boom');
    });
  });

  group('other exceptions', () {
    test('the sealed hierarchy switches exhaustively', () {
      final errors = <SupDeskException>[
        const SupDeskConfigurationException('bad'),
        const SupDeskConnectionException(),
        SupDeskTimeoutException(const Duration(seconds: 2)),
        RequestTooLargeException(2, 1),
        const SupDeskSignatureVerificationException(),
        build(),
      ];

      // No default arm: this only compiles while every subclass is covered,
      // which is the point of sealing the base class.
      final labels = errors.map(
        (error) => switch (error) {
          SupDeskConfigurationException() => 'config',
          SupDeskConnectionException() => 'connection',
          SupDeskTimeoutException() => 'timeout',
          RequestTooLargeException() => 'too-large',
          SupDeskSignatureVerificationException() => 'signature',
          SupDeskApiException() => 'api',
        },
      );

      expect(labels, [
        'config',
        'connection',
        'timeout',
        'too-large',
        'signature',
        'api',
      ]);
      expect(errors.every((error) => error.message.isNotEmpty), isTrue);
    });

    test('timeout names the deadline it blew', () {
      final error = SupDeskTimeoutException(const Duration(milliseconds: 250));

      expect(error.timeout, const Duration(milliseconds: 250));
      expect(error.message, 'Request timed out after 250ms.');
      expect(error.toString(), contains('SupDeskTimeoutException'));
    });

    test('request-too-large names both sizes', () {
      final error = RequestTooLargeException(2000, 1000);

      expect(error.size, 2000);
      expect(error.limit, 1000);
      expect(error.message, contains('2000 bytes'));
      expect(error.message, contains('1000 byte'));
    });

    test('connection exception keeps its cause', () {
      final cause = StateError('socket');
      const message = 'nope';
      final error = SupDeskConnectionException(message, cause);

      expect(error.cause, same(cause));
      expect(error.message, message);
    });
  });
}
