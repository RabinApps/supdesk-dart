import 'package:dio/dio.dart';
import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

import '../helpers/mock_adapter.dart';

void main() {
  group('request building', () {
    test('joins the base URL, path and query string', () async {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': null}),
      ]);

      await httpClientWith(adapter).request(
        method: 'GET',
        path: '/submissions',
        query: {'status': 'open', 'limit': 5, 'skip': null},
      );

      expect(
        adapter.calls.single.uri.toString(),
        'https://api.example.test/v1/submissions?status=open&limit=5',
      );
    });

    test('sends the documented headers', () async {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': null}),
      ]);

      await httpClientWith(adapter).request(method: 'GET', path: '/feedback');

      final call = adapter.calls.single;
      expect(call.header('authorization'), 'Bearer sd_test_key');
      expect(call.header('accept'), 'application/json');
      expect(call.header('user-agent'), 'supdesk-dart/$packageVersion');
      expect(call.header('content-type'), isNull);
    });

    test('layers default headers under per-call headers', () async {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': null}),
      ]);

      await httpClientWith(
        adapter,
        defaultHeaders: {'X-App': 'my-service', 'X-Env': 'prod'},
      ).request(
        method: 'GET',
        path: '/feedback',
        headers: {'x-env': 'staging'},
      );

      final call = adapter.calls.single;
      expect(call.header('x-app'), 'my-service');
      expect(call.header('x-env'), 'staging');
    });

    test('never lets a caller replace the authorization header', () async {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': null}),
      ]);

      await httpClientWith(
        adapter,
        defaultHeaders: {'Authorization': 'Bearer leaked'},
      ).request(
        method: 'GET',
        path: '/feedback',
        headers: {'authorization': 'Bearer also-leaked'},
      );

      expect(
          adapter.calls.single.header('authorization'), 'Bearer sd_test_key');
    });

    test('encodes a JSON body and marks its content type', () async {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': null}),
      ]);

      await httpClientWith(adapter).request(
        method: 'POST',
        path: '/feedback',
        body: {'title': 'hi', 'count': 2},
      );

      final call = adapter.calls.single;
      expect(call.header('content-type'), 'application/json');
      expect(call.json, {'title': 'hi', 'count': 2});
    });

    test('rejects a body over the 1 MB API cap before sending', () async {
      final adapter = MockAdapter([]);
      final oversized = {'body': 'x' * (maxRequestBytes + 1)};

      await expectLater(
        httpClientWith(adapter)
            .request(method: 'POST', path: '/feedback', body: oversized),
        throwsA(
          isA<RequestTooLargeException>()
              .having((error) => error.limit, 'limit', maxRequestBytes)
              .having(
                  (error) => error.size, 'size', greaterThan(maxRequestBytes)),
        ),
      );
      expect(adapter.calls, isEmpty);
    });
  });

  group('response parsing', () {
    test('returns null for 204', () async {
      final adapter = MockAdapter([const MockResponse(status: 204)]);

      expect(
        await httpClientWith(adapter).request(method: 'DELETE', path: '/x/1'),
        isNull,
      );
    });

    test('returns null for an empty 200 body', () async {
      final adapter = MockAdapter([const MockResponse(text: '')]);

      expect(
        await httpClientWith(adapter).request(method: 'GET', path: '/x'),
        isNull,
      );
    });

    test('surfaces an unparseable 200 body as an API error, not a crash', () {
      final adapter = MockAdapter([
        const MockResponse(text: '<html>gateway</html>'),
      ]);

      expect(
        httpClientWith(adapter).request(method: 'GET', path: '/x'),
        throwsA(
          isA<InternalServerException>()
              .having((error) => error.body, 'body', '<html>gateway</html>'),
        ),
      );
    });

    test('maps the error envelope to a typed exception', () {
      final adapter = MockAdapter([
        MockResponse(
          status: 404,
          json: errorBody('not_found', 'no submission with that id'),
          headers: {'x-request-id': 'req_1'},
        ),
      ]);

      expect(
        httpClientWith(adapter).request(method: 'POST', path: '/x'),
        throwsA(
          isA<NotFoundException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.code, 'code', 'not_found')
              .having(
                (error) => error.message,
                'message',
                'no submission with that id',
              )
              .having((error) => error.requestId, 'requestId', 'req_1'),
        ),
      );
    });

    test('falls back to a status message when the body is not an envelope', () {
      final adapter = MockAdapter([
        const MockResponse(status: 502, text: '<html>bad gateway</html>'),
      ]);

      expect(
        httpClientWith(adapter, maxRetries: 0)
            .request(method: 'GET', path: '/x'),
        throwsA(
          isA<InternalServerException>().having(
            (error) => error.message,
            'message',
            'SupDesk API request failed with status 502.',
          ),
        ),
      );
    });

    test('falls back when the envelope carries an empty message', () {
      final adapter = MockAdapter([
        const MockResponse(
          status: 400,
          json: {
            'error': {'code': 'invalid_request', 'message': ''},
          },
        ),
      ]);

      expect(
        httpClientWith(adapter).request(method: 'GET', path: '/x'),
        throwsA(
          isA<InvalidRequestException>()
              .having((error) => error.code, 'code', 'invalid_request')
              .having(
                (error) => error.message,
                'message',
                'SupDesk API request failed with status 400.',
              ),
        ),
      );
    });

    test('tolerates a malformed envelope', () {
      final adapter = MockAdapter([
        const MockResponse(status: 400, json: {'error': 'nope'}),
      ]);

      expect(
        httpClientWith(adapter).request(method: 'GET', path: '/x'),
        throwsA(
          isA<InvalidRequestException>()
              .having((error) => error.code, 'code', ''),
        ),
      );
    });
  });

  group('parseResponse', () {
    test('reads a JSON object', () {
      expect(parseResponse(statusCode: 200, body: '{"a":1}'), {'a': 1});
    });

    test('treats a JSON null body as no content', () {
      expect(parseResponse(statusCode: 200, body: 'null'), isNull);
    });

    test('ignores a body sent with 204', () {
      expect(parseResponse(statusCode: 204, body: '{"a":1}'), isNull);
    });
  });

  group('transport failures', () {
    test('maps a timeout to SupDeskTimeoutException', () {
      final client = httpClientWith(
        HangingAdapter(),
        timeout: const Duration(milliseconds: 20),
      );

      expect(
        client.request(method: 'GET', path: '/x'),
        throwsA(
          isA<SupDeskTimeoutException>().having(
            (error) => error.timeout,
            'timeout',
            const Duration(milliseconds: 20),
          ),
        ),
      );
    });

    test('honours a per-call timeout override', () {
      final client = httpClientWith(HangingAdapter());

      expect(
        client.request(
          method: 'GET',
          path: '/x',
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<SupDeskTimeoutException>()),
      );
    });

    test('maps a dio timeout type to SupDeskTimeoutException', () {
      final adapter = MockAdapter([
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        ),
      ]);

      expect(
        httpClientWith(adapter, maxRetries: 0)
            .request(method: 'GET', path: '/x'),
        throwsA(isA<SupDeskTimeoutException>()),
      );
    });

    test('maps a connection error', () {
      final adapter = MockAdapter([
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
          message: 'socket closed',
        ),
      ]);

      expect(
        httpClientWith(adapter, maxRetries: 0)
            .request(method: 'GET', path: '/x'),
        throwsA(
          isA<SupDeskConnectionException>()
              .having((error) => error.message, 'message',
                  contains('socket closed'))
              .having((error) => error.cause, 'cause', isA<DioException>()),
        ),
      );
    });

    test('maps an unexpected adapter failure', () {
      final adapter = MockAdapter([StateError('kaboom')]);

      expect(
        httpClientWith(adapter, maxRetries: 0)
            .request(method: 'GET', path: '/x'),
        throwsA(isA<SupDeskConnectionException>()),
      );
    });

    test('maps a badResponse from an injected Dio that validates statuses', () {
      final adapter = MockAdapter([
        DioException.badResponse(
          statusCode: 404,
          requestOptions: RequestOptions(path: '/x'),
          response: Response<String>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 404,
            data: '{"error":{"code":"not_found","message":"gone"}}',
          ),
        ),
      ]);

      expect(
        httpClientWith(adapter, maxRetries: 0)
            .request(method: 'GET', path: '/x'),
        throwsA(
          isA<NotFoundException>()
              .having((error) => error.message, 'message', 'gone'),
        ),
      );
    });

    test('passes caller cancellation through untouched', () {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': null})
      ]);
      final token = CancelToken()..cancel('caller changed their mind');

      expect(
        httpClientWith(adapter)
            .request(method: 'GET', path: '/x', cancelToken: token),
        throwsA(
          isA<DioException>()
              .having((error) => error.type, 'type', DioExceptionType.cancel),
        ),
      );
    });
  });

  group('retries', () {
    test('retries a 5xx and returns the eventual success', () async {
      final sleeps = <Duration>[];
      final adapter = MockAdapter([
        const MockResponse(status: 500, text: ''),
        const MockResponse(json: {'data': 'ok'}),
      ]);

      final result = await httpClientWith(adapter, sleeps: sleeps)
          .request(method: 'GET', path: '/x');

      expect(result, {'data': 'ok'});
      expect(adapter.calls, hasLength(2));
      expect(sleeps, [baseRetryDelay]);
    });

    test('gives up after maxRetries and rethrows the last failure', () {
      final sleeps = <Duration>[];
      final adapter = MockAdapter([
        const MockResponse(status: 500, text: ''),
        const MockResponse(status: 500, text: ''),
        const MockResponse(status: 500, text: ''),
      ]);

      expect(
        httpClientWith(adapter, sleeps: sleeps)
            .request(method: 'GET', path: '/x')
            .catchError((Object error) {
          expect(adapter.calls, hasLength(3));
          expect(sleeps, [baseRetryDelay, baseRetryDelay * 2]);
          throw error;
        }),
        throwsA(isA<InternalServerException>()),
      );
    });

    test('does not replay a metered POST', () async {
      final adapter = MockAdapter([
        const MockResponse(status: 500, text: ''),
      ]);

      await expectLater(
        httpClientWith(adapter).request(method: 'POST', path: '/submissions'),
        throwsA(isA<InternalServerException>()),
      );
      expect(adapter.calls, hasLength(1));
    });

    test('replays a POST when the caller opts in', () async {
      final adapter = MockAdapter([
        const MockResponse(status: 500, text: ''),
        const MockResponse(json: {'data': 'ok'}),
      ]);

      await httpClientWith(adapter, retryUnsafeMethods: true)
          .request(method: 'POST', path: '/submissions');

      expect(adapter.calls, hasLength(2));
    });

    test('never retries limit_reached', () async {
      final adapter = MockAdapter([
        MockResponse(status: 429, json: errorBody('limit_reached')),
      ]);

      await expectLater(
        httpClientWith(adapter).request(method: 'GET', path: '/x'),
        throwsA(isA<LimitReachedException>()),
      );
      expect(adapter.calls, hasLength(1));
    });

    test('honours Retry-After over the computed backoff', () async {
      final sleeps = <Duration>[];
      final adapter = MockAdapter([
        MockResponse(
          status: 429,
          json: errorBody('rate_limited'),
          headers: {'retry-after': '2'},
        ),
        const MockResponse(json: {'data': 'ok'}),
      ]);

      await httpClientWith(adapter, sleeps: sleeps)
          .request(method: 'GET', path: '/x');

      expect(sleeps, [const Duration(seconds: 2)]);
    });
  });

  group('lifecycle', () {
    test('close leaves an injected Dio alone', () async {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': null}),
        const MockResponse(json: {'data': null}),
      ]);
      final dio = dioWith(adapter);
      final client = SupDeskHttpClient(
        apiKey: 'sd_test_key',
        baseUrl: 'https://api.example.test/v1',
        dio: dio,
      );

      await client.request(method: 'GET', path: '/x');
      client.close();

      // Still usable: the caller owns this Dio.
      await client.request(method: 'GET', path: '/x');
      expect(adapter.calls, hasLength(2));
      expect(client.dio, same(dio));
    });

    test('close disposes a Dio the client created', () {
      final client = SupDeskHttpClient(apiKey: 'sd_test_key');

      expect(client.close, returnsNormally);
    });
  });
}
