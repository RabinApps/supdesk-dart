import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

import 'helpers/mock_adapter.dart';

void main() {
  group('construction', () {
    test('requires an API key', () {
      expect(
        () => SupDesk(apiKey: ''),
        throwsA(
          isA<SupDeskConfigurationException>().having(
            (error) => error.message,
            'message',
            contains('API key is required'),
          ),
        ),
      );
    });

    test('refuses to start in a Flutter or web build', () {
      expect(
        () => SupDesk(apiKey: 'sd_live_x', isClientSideRuntime: () => true),
        throwsA(
          isA<SupDeskConfigurationException>()
              .having(
                  (error) => error.message, 'message', contains('rotate it'))
              .having(
                (error) => error.message,
                'message',
                contains('dangerouslyAllowClientSide'),
              ),
        ),
      );
    });

    test('yields to dangerouslyAllowClientSide', () {
      final client = SupDesk(
        apiKey: 'sd_live_x',
        isClientSideRuntime: () => true,
        dangerouslyAllowClientSide: true,
      );

      expect(client.submissions, isA<Submissions>());
      client.close();
    });

    test('checks the real runtime when no predicate is injected', () {
      // These tests run on the VM, which is neither Flutter nor web.
      expect(defaultIsClientSideRuntime(), isFalse);
      expect(isFlutterRuntime, isFalse);
      expect(isWebRuntime, isFalse);

      final client = SupDesk(apiKey: 'sd_live_x');

      expect(client.http.baseUrl, defaultBaseUrl);
      client.close();
    });

    test('applies the documented defaults', () {
      final client = SupDesk(apiKey: 'sd_live_x');

      expect(client.http.timeout, defaultTimeout);
      expect(client.http.maxRetries, defaultMaxRetries);
      expect(client.http.retryUnsafeMethods, isFalse);
      expect(client.http.defaultHeaders, isEmpty);
      client.close();
    });

    test('passes every option through to the transport', () {
      final client = SupDesk(
        apiKey: 'sd_live_x',
        baseUrl: 'https://proxy.example.test/v1',
        timeout: const Duration(seconds: 5),
        maxRetries: 7,
        retryUnsafeMethods: true,
        defaultHeaders: {'X-App': 'mine'},
      );

      expect(client.http.apiKey, 'sd_live_x');
      expect(client.http.baseUrl, 'https://proxy.example.test/v1');
      expect(client.http.timeout, const Duration(seconds: 5));
      expect(client.http.maxRetries, 7);
      expect(client.http.retryUnsafeMethods, isTrue);
      // Header names are normalized so a caller cannot shadow one by casing.
      expect(client.http.defaultHeaders, {'x-app': 'mine'});
      client.close();
    });

    test('exposes every resource', () {
      final client = clientWith(MockAdapter([]));

      expect(client.submissions, isA<Submissions>());
      expect(client.feedback, isA<FeedbackResource>());
      expect(client.changelog, isA<Changelog>());
      expect(client.messages, isA<Messages>());
      expect(client.waitlist, isA<Waitlist>());
      expect(client.beta.programs, isA<BetaPrograms>());
      expect(client.beta.testers, isA<BetaTesters>());
      expect(client.articles, isA<Articles>());
      expect(client.articleCategories, isA<ArticleCategories>());
    });
  });

  group('end to end', () {
    test('reads through the injected Dio', () async {
      final adapter = MockAdapter([
        MockResponse(
          json: {
            'data': {
              'id': 'sub_1',
              'type': 'bug',
              'title': 'Export does nothing',
              'body': 'No effect.',
              'status': 'open',
              'created_at': '2026-01-02T03:04:05Z',
            },
          },
        ),
      ]);

      final submission = await clientWith(adapter).submissions.get('sub_1');

      expect(submission.id, 'sub_1');
      expect(submission.type, SubmissionType.bug);
      expect(submission.status, PostStatus.open);
      expect(submission.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(
        adapter.calls.single.uri.path,
        '/v1/submissions/sub_1',
      );
    });

    test('close is safe to call', () {
      final client = clientWith(MockAdapter([]));

      expect(client.close, returnsNormally);
    });

    test('surfaces a malformed envelope as an API error', () {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': 'not-an-object'}),
      ]);

      expect(
        clientWith(adapter).submissions.get('sub_1'),
        throwsA(
          isA<SupDeskApiException>().having(
            (error) => error.message,
            'message',
            contains('did not contain an object'),
          ),
        ),
      );
    });

    test('surfaces a malformed search payload as an API error', () {
      final adapter = MockAdapter([
        const MockResponse(json: {'data': 'not-a-list'}),
      ]);

      expect(
        clientWith(adapter).articles.search('export'),
        throwsA(
          isA<SupDeskApiException>().having(
            (error) => error.message,
            'message',
            contains('did not contain an array'),
          ),
        ),
      );
    });

    test('surfaces a malformed list envelope as an API error', () {
      final adapter = MockAdapter([const MockResponse(text: '[]')]);

      expect(
        clientWith(adapter).submissions.list(),
        throwsA(
          isA<SupDeskApiException>().having(
            (error) => error.message,
            'message',
            contains('did not contain a paginated envelope'),
          ),
        ),
      );
    });

    test('defaults pagination when the server omits it', () async {
      final adapter = MockAdapter([
        const MockResponse(
          json: {
            'data': [
              {'id': 'sub_1'},
            ],
          },
        ),
      ]);

      final page = await clientWith(adapter).submissions.list();

      expect(page.pagination,
          const PaginationMeta(limit: 1, offset: 0, hasMore: false));
      expect(page.hasNextPage(), isFalse);
    });
  });
}
