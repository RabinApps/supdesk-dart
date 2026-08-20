import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

import '../helpers/mock_adapter.dart';

/// Asserts that one resource method issues exactly the request it documents.
void endpoint(
  String name, {
  required Future<void> Function(SupDesk client) call,
  required String method,
  required String path,
  String query = '',
  Object? body,
  MockResponse? response,
}) {
  test(name, () async {
    final adapter = MockAdapter([
      response ?? MockResponse(json: {'data': <String, Object?>{}}),
    ]);

    await call(clientWith(adapter));

    final request = adapter.calls.single;
    expect(request.method, method, reason: 'method');
    expect(request.uri.path, '/v1$path', reason: 'path');
    expect(request.uri.query, query, reason: 'query');
    expect(request.body, body, reason: 'body');
  });
}

MockResponse get emptyPage => MockResponse(json: pageOf([]));

MockResponse get noContent => const MockResponse(status: 204);

void main() {
  group('submissions', () {
    endpoint(
      'list',
      call: (client) => client.submissions.list(
        status: PostStatus.open,
        type: SubmissionType.bug,
        limit: 10,
        offset: 20,
      ),
      method: 'GET',
      path: '/submissions',
      query: 'status=open&type=bug&limit=10&offset=20',
      response: emptyPage,
    );

    endpoint(
      'list by backlog status',
      call: (client) => client.submissions.list(status: PostStatus.backlog),
      method: 'GET',
      path: '/submissions',
      query: 'status=backlog',
      response: emptyPage,
    );

    endpoint(
      'list without filters',
      call: (client) => client.submissions.list(),
      method: 'GET',
      path: '/submissions',
      response: emptyPage,
    );

    endpoint(
      'get',
      call: (client) => client.submissions.get('sub_1'),
      method: 'GET',
      path: '/submissions/sub_1',
    );

    endpoint(
      'create',
      call: (client) => client.submissions.create(
        type: SubmissionType.feature,
        title: 'Dark mode',
        email: 'user@example.com',
        body: 'Please.',
        name: 'Ada',
        locale: SupDeskLocale.ar,
      ),
      method: 'POST',
      path: '/submissions',
      body: {
        'type': 'feature',
        'title': 'Dark mode',
        'email': 'user@example.com',
        'body': 'Please.',
        'name': 'Ada',
        'locale': 'ar',
      },
    );

    endpoint(
      'create omits unset optional fields',
      call: (client) => client.submissions.create(
        type: SubmissionType.bug,
        title: 'Broken',
        email: 'user@example.com',
      ),
      method: 'POST',
      path: '/submissions',
      body: {
        'type': 'bug',
        'title': 'Broken',
        'email': 'user@example.com',
      },
    );
  });

  group('feedback', () {
    endpoint(
      'list',
      call: (client) => client.feedback.list(status: PostStatus.done, limit: 5),
      method: 'GET',
      path: '/feedback',
      query: 'status=done&limit=5',
      response: emptyPage,
    );

    endpoint(
      'get',
      call: (client) => client.feedback.get('fb_1'),
      method: 'GET',
      path: '/feedback/fb_1',
    );

    endpoint(
      'create',
      call: (client) => client.feedback.create(
        title: 'Love it',
        email: 'user@example.com',
      ),
      method: 'POST',
      path: '/feedback',
      body: {'title': 'Love it', 'email': 'user@example.com'},
    );
  });

  group('changelog', () {
    endpoint(
      'list',
      call: (client) => client.changelog.list(locale: SupDeskLocale.fr),
      method: 'GET',
      path: '/changelog',
      query: 'locale=fr',
      response: emptyPage,
    );

    endpoint(
      'get with locale',
      call: (client) => client.changelog.get('cl_1', locale: SupDeskLocale.ja),
      method: 'GET',
      path: '/changelog/cl_1',
      query: 'locale=ja',
    );

    endpoint(
      'create',
      call: (client) => client.changelog.create(
        title: '1.2.0',
        body: '## Fixes',
        labels: ['Fixed', 'Improved'],
        version: '1.2.0',
        status: ChangelogStatus.published,
        locale: SupDeskLocale.en,
      ),
      method: 'POST',
      path: '/changelog',
      body: {
        'title': '1.2.0',
        'body': '## Fixes',
        'labels': ['Fixed', 'Improved'],
        'version': '1.2.0',
        'status': 'published',
        'locale': 'en',
      },
    );

    endpoint(
      'update',
      call: (client) =>
          client.changelog.update('cl_1', status: ChangelogStatus.draft),
      method: 'PATCH',
      path: '/changelog/cl_1',
      body: {'status': 'draft'},
    );

    endpoint(
      'delete',
      call: (client) => client.changelog.delete('cl_1'),
      method: 'DELETE',
      path: '/changelog/cl_1',
      response: noContent,
    );
  });

  group('messages', () {
    endpoint(
      'list',
      call: (client) => client.messages.list(status: ThreadStatus.open),
      method: 'GET',
      path: '/messages',
      query: 'status=open',
      response: emptyPage,
    );

    endpoint(
      'get',
      call: (client) => client.messages.get('th_1'),
      method: 'GET',
      path: '/messages/th_1',
    );

    endpoint(
      'create',
      call: (client) => client.messages.create(
        email: 'user@example.com',
        name: 'Ada',
        subject: 'Billing',
        body: 'Question about my invoice.',
        locale: SupDeskLocale.es,
      ),
      method: 'POST',
      path: '/messages',
      body: {
        'email': 'user@example.com',
        'name': 'Ada',
        'subject': 'Billing',
        'body': 'Question about my invoice.',
        'locale': 'es',
      },
    );

    endpoint(
      'update',
      call: (client) => client.messages.update(
        'th_1',
        status: ThreadStatus.closed,
        subject: 'Resolved',
      ),
      method: 'PATCH',
      path: '/messages/th_1',
      body: {'status': 'closed', 'subject': 'Resolved'},
    );

    endpoint(
      'delete',
      call: (client) => client.messages.delete('th_1'),
      method: 'DELETE',
      path: '/messages/th_1',
      response: noContent,
    );

    endpoint(
      'addMessage',
      call: (client) => client.messages.addMessage(
        'th_1',
        body: 'On it.',
        sender: MessageSender.member,
      ),
      method: 'POST',
      path: '/messages/th_1/messages',
      body: {'body': 'On it.', 'sender': 'member'},
    );
  });

  group('waitlist', () {
    endpoint(
      'list',
      call: (client) => client.waitlist.list(
        search: 'ada@',
        status: WaitlistStatus.waiting,
      ),
      method: 'GET',
      path: '/waitlist/signups',
      query: 'search=ada%40&status=waiting',
      response: emptyPage,
    );

    endpoint(
      'get',
      call: (client) => client.waitlist.get('wl_1'),
      method: 'GET',
      path: '/waitlist/signups/wl_1',
    );

    endpoint(
      'create',
      call: (client) => client.waitlist.create(
        email: 'ada@example.com',
        referralCode: 'ABC123',
      ),
      method: 'POST',
      path: '/waitlist/signups',
      body: {'email': 'ada@example.com', 'referral_code': 'ABC123'},
    );

    endpoint(
      'update',
      call: (client) =>
          client.waitlist.update('wl_1', status: WaitlistStatus.invited),
      method: 'PATCH',
      path: '/waitlist/signups/wl_1',
      body: {'status': 'invited'},
    );

    endpoint(
      'delete',
      call: (client) => client.waitlist.delete('wl_1'),
      method: 'DELETE',
      path: '/waitlist/signups/wl_1',
      response: noContent,
    );
  });

  group('beta.programs', () {
    endpoint(
      'list',
      call: (client) => client.beta.programs.list(status: 'active'),
      method: 'GET',
      path: '/beta/programs',
      query: 'status=active',
      response: emptyPage,
    );

    endpoint(
      'get',
      call: (client) => client.beta.programs.get('bp_1'),
      method: 'GET',
      path: '/beta/programs/bp_1',
    );

    endpoint(
      'create',
      call: (client) => client.beta.programs.create(
        name: 'Autumn beta',
        version: '2.0.0-beta.1',
        summary: 'New editor',
        accessUrl: 'https://example.test/beta',
        accessInstructions: 'Install TestFlight',
        status: 'active',
        allowPublicSignup: true,
        feedbackDeadline: DateTime.utc(2026, 9, 30),
      ),
      method: 'POST',
      path: '/beta/programs',
      body: {
        'name': 'Autumn beta',
        'version': '2.0.0-beta.1',
        'summary': 'New editor',
        'access_url': 'https://example.test/beta',
        'access_instructions': 'Install TestFlight',
        'status': 'active',
        'allow_public_signup': true,
        'feedback_deadline': '2026-09-30T00:00:00.000Z',
      },
    );

    endpoint(
      'update',
      call: (client) =>
          client.beta.programs.update('bp_1', allowPublicSignup: false),
      method: 'PATCH',
      path: '/beta/programs/bp_1',
      body: {'allow_public_signup': false},
    );

    endpoint(
      'delete',
      call: (client) => client.beta.programs.delete('bp_1'),
      method: 'DELETE',
      path: '/beta/programs/bp_1',
      response: noContent,
    );
  });

  group('beta.testers', () {
    endpoint(
      'list',
      call: (client) =>
          client.beta.testers.list('bp_1', status: 'invited', limit: 50),
      method: 'GET',
      path: '/beta/programs/bp_1/testers',
      query: 'status=invited&limit=50',
      response: emptyPage,
    );

    endpoint(
      'get',
      call: (client) => client.beta.testers.get('bp_1', 'bt_1'),
      method: 'GET',
      path: '/beta/programs/bp_1/testers/bt_1',
    );

    endpoint(
      'create',
      call: (client) =>
          client.beta.testers.create('bp_1', email: 'ada@example.com'),
      method: 'POST',
      path: '/beta/programs/bp_1/testers',
      body: {'email': 'ada@example.com'},
    );

    endpoint(
      'delete',
      call: (client) => client.beta.testers.delete('bp_1', 'bt_1'),
      method: 'DELETE',
      path: '/beta/programs/bp_1/testers/bt_1',
      response: noContent,
    );
  });

  group('articles', () {
    endpoint(
      'list',
      call: (client) => client.articles.list(
        status: ArticleStatus.published,
        categoryId: 'cat_1',
      ),
      method: 'GET',
      path: '/articles',
      query: 'status=published&category_id=cat_1',
      response: emptyPage,
    );

    endpoint(
      'search',
      call: (client) => client.articles.search('how to export', limit: 5),
      method: 'GET',
      path: '/articles/search',
      query: 'q=how+to+export&limit=5',
      response: const MockResponse(json: {'data': <Object?>[]}),
    );

    endpoint(
      'get',
      call: (client) => client.articles.get('art_1'),
      method: 'GET',
      path: '/articles/art_1',
    );

    endpoint(
      'create',
      call: (client) => client.articles.create(
        title: 'How to export',
        body: '# Export',
        excerpt: 'Exporting data',
        slug: 'how-to-export',
        categoryId: 'cat_1',
      ),
      method: 'POST',
      path: '/articles',
      body: {
        'title': 'How to export',
        'body': '# Export',
        'excerpt': 'Exporting data',
        'slug': 'how-to-export',
        'category_id': 'cat_1',
      },
    );

    endpoint(
      'update publishes',
      call: (client) =>
          client.articles.update('art_1', status: ArticleStatus.published),
      method: 'PATCH',
      path: '/articles/art_1',
      body: {'status': 'published'},
    );

    endpoint(
      'delete',
      call: (client) => client.articles.delete('art_1'),
      method: 'DELETE',
      path: '/articles/art_1',
      response: noContent,
    );
  });

  group('articleCategories', () {
    endpoint(
      'list',
      call: (client) => client.articleCategories.list(limit: 25, offset: 25),
      method: 'GET',
      path: '/article-categories',
      query: 'limit=25&offset=25',
      response: emptyPage,
    );

    endpoint(
      'get',
      call: (client) => client.articleCategories.get('cat_1'),
      method: 'GET',
      path: '/article-categories/cat_1',
    );

    endpoint(
      'create',
      call: (client) => client.articleCategories.create(
        name: 'Billing',
        description: 'Invoices and plans',
        sortOrder: 2,
      ),
      method: 'POST',
      path: '/article-categories',
      body: {
        'name': 'Billing',
        'description': 'Invoices and plans',
        'sort_order': 2,
      },
    );

    endpoint(
      'update',
      call: (client) => client.articleCategories.update('cat_1', name: 'Plans'),
      method: 'PATCH',
      path: '/article-categories/cat_1',
      body: {'name': 'Plans'},
    );

    endpoint(
      'delete',
      call: (client) => client.articleCategories.delete('cat_1'),
      method: 'DELETE',
      path: '/article-categories/cat_1',
      response: noContent,
    );
  });

  group('ids are escaped', () {
    endpoint(
      'a hostile id cannot rewrite the route',
      call: (client) => client.articles.get('../../admin'),
      method: 'GET',
      path: '/articles/..%2F..%2Fadmin',
    );
  });

  group('call options', () {
    test('apply per-call headers and timeout', () async {
      final adapter = MockAdapter([
        MockResponse(json: {'data': <String, Object?>{}}),
      ]);

      await clientWith(adapter).articles.get(
            'art_1',
            options: const CallOptions(
              headers: {'X-Trace': 'abc'},
              timeout: Duration(seconds: 5),
            ),
          );

      expect(adapter.calls.single.header('x-trace'), 'abc');
    });

    test('carry a cancel token', () {
      final adapter = MockAdapter([
        MockResponse(json: {'data': <String, Object?>{}}),
      ]);
      final token = CancelToken()..cancel();

      expect(
        clientWith(adapter)
            .articles
            .get('art_1', options: CallOptions(cancelToken: token)),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('paging across resources', () {
    test('streams every page of submissions', () async {
      final adapter = MockAdapter([
        MockResponse(
          json: pageOf(
            [
              {'id': 'sub_1'},
              {'id': 'sub_2'},
            ],
            limit: 2,
            hasMore: true,
          ),
        ),
        MockResponse(
          json: pageOf(
            [
              {'id': 'sub_3'},
            ],
            limit: 2,
            offset: 2,
          ),
        ),
      ]);

      final page = await clientWith(adapter).submissions.list(limit: 2);
      final ids = await page.autoPaging().map((s) => s.id).toList();

      expect(ids, ['sub_1', 'sub_2', 'sub_3']);
      expect(adapter.calls, hasLength(2));
      expect(adapter.calls.last.uri.query, 'limit=2&offset=2');
    });

    test('search returns a plain ranked list, not a page', () async {
      final adapter = MockAdapter([
        const MockResponse(
          json: {
            'data': [
              {'id': 'art_1', 'title': 'Export', 'rank': 0.8},
              {'id': 'art_2', 'title': 'Import', 'rank': 0.2},
            ],
          },
        ),
      ]);

      final results = await clientWith(adapter).articles.search('port');

      expect(results, hasLength(2));
      expect(results.first.rank, 0.8);
      expect(results.last.id, 'art_2');
    });
  });
}
