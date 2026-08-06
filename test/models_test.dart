import 'package:supdesk/src/models/json.dart';
import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

void main() {
  group('json helpers', () {
    test('coerce or fall back rather than throw', () {
      expect(stringOrEmpty('a'), 'a');
      expect(stringOrEmpty(null), '');
      expect(stringOrEmpty(7), '');

      expect(stringOrNull('a'), 'a');
      expect(stringOrNull(null), isNull);

      expect(intOrZero(3), 3);
      expect(intOrZero(3.7), 3);
      expect(intOrZero('3'), 0);

      expect(intOrNull(3), 3);
      expect(intOrNull(null), isNull);

      expect(boolOrFalse(true), isTrue);
      expect(boolOrFalse('true'), isFalse);

      expect(dateTimeOrNull('2026-01-02T03:04:05Z'),
          DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(dateTimeOrNull('not a date'), isNull);
      expect(dateTimeOrNull(null), isNull);
    });

    test('filter collections to the expected element types', () {
      expect(stringList(['a', 1, 'b']), ['a', 'b']);
      expect(stringList('a'), isEmpty);

      expect(objectOrNull({'a': 1}), {'a': 1});
      expect(objectOrNull('a'), isNull);

      expect(
        objectList([
          {'a': 1},
          'skip',
        ]),
        [
          {'a': 1},
        ],
      );
      expect(objectList(null), isEmpty);
    });

    test('pruneNulls drops unset parameters', () {
      expect(pruneNulls({'a': 1, 'b': null, 'c': false}), {'a': 1, 'c': false});
    });

    test('listEquals compares element-wise', () {
      final list = [1, 2];

      expect(listEquals(list, list), isTrue);
      expect(listEquals([1, 2], [1, 2]), isTrue);
      expect(listEquals([1, 2], [1, 3]), isFalse);
      expect(listEquals([1], [1, 2]), isFalse);
    });
  });

  group('open unions', () {
    test('keep a value the SDK has never heard of', () {
      const status = PostStatus('under_review');

      expect(status.value, 'under_review');
      expect(PostStatus.values, isNot(contains(status)));
    });

    test('compare by their string value', () {
      expect(const PostStatus('open'), PostStatus.open);
      expect(SubmissionType.bug.value, 'bug');
      expect(SupDeskLocale.values, hasLength(8));
      expect(ChangelogStatus.values, hasLength(3));
      expect(ThreadStatus.values, hasLength(2));
      expect(MessageSender.endUser.value, 'end_user');
      expect(WaitlistStatus.values, hasLength(3));
      expect(ArticleStatus.values, hasLength(3));
      expect(BetaTesterStatus.values, hasLength(2));
    });
  });

  group('Submission', () {
    const json = {
      'id': 'sub_1',
      'type': 'bug',
      'title': 'Export button does nothing',
      'body': 'No effect.',
      'status': 'in_progress',
      'created_at': '2026-01-02T03:04:05.000Z',
    };

    test('round-trips', () {
      final submission = Submission.fromJson(json);

      expect(submission.id, 'sub_1');
      expect(submission.type, SubmissionType.bug);
      expect(submission.status, PostStatus.inProgress);
      expect(submission.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(submission.toJson(), json);
      expect(Submission.fromJson(submission.toJson()), submission);
      expect(submission.hashCode, Submission.fromJson(json).hashCode);
      expect(submission.toString(), contains('sub_1'));
    });

    test('survives an empty payload', () {
      final submission = Submission.fromJson(const {});

      expect(submission.id, '');
      expect(submission.createdAt, isNull);
      expect(submission, isNot(Submission.fromJson(json)));
    });
  });

  group('Feedback', () {
    test('round-trips', () {
      const json = {
        'id': 'fb_1',
        'type': 'feedback',
        'title': 'Love it',
        'body': '',
        'status': 'open',
        'created_at': '2026-01-02T03:04:05.000Z',
      };

      final feedback = Feedback.fromJson(json);

      expect(feedback.type, 'feedback');
      expect(feedback.status, PostStatus.open);
      expect(feedback.toJson(), json);
      expect(Feedback.fromJson(json), feedback);
      expect(feedback.hashCode, Feedback.fromJson(json).hashCode);
      expect(feedback.toString(), contains('fb_1'));
    });
  });

  group('ChangelogEntry', () {
    test('round-trips, including labels', () {
      const json = {
        'id': 'cl_1',
        'title': '1.2.0',
        'body': '## Fixed',
        'labels': ['Fixed', 'Improved'],
        'locale': 'en',
        'version': '1.2.0',
        'published_at': '2026-01-02T03:04:05.000Z',
      };

      final entry = ChangelogEntry.fromJson(json);

      expect(entry.labels, ['Fixed', 'Improved']);
      expect(entry.locale, SupDeskLocale.en);
      expect(entry.toJson(), json);
      expect(ChangelogEntry.fromJson(json), entry);
      expect(entry.hashCode, ChangelogEntry.fromJson(json).hashCode);
      expect(entry.toString(), contains('1.2.0'));
    });

    test('keeps published_at null for a draft', () {
      final entry = ChangelogEntry.fromJson(const {
        'id': 'cl_2',
        'published_at': null,
      });

      expect(entry.publishedAt, isNull);
      expect(entry.labels, isEmpty);
    });

    test('differs when a label differs', () {
      final a = ChangelogEntry.fromJson(const {
        'id': 'cl_1',
        'labels': ['Fixed'],
      });
      final b = ChangelogEntry.fromJson(const {
        'id': 'cl_1',
        'labels': ['New'],
      });

      expect(a, isNot(b));
    });
  });

  group('messages', () {
    const messageJson = {
      'id': 'msg_1',
      'sender': 'member',
      'member_id': 'mem_1',
      'body': 'On it.',
      'via': 'api',
      'created_at': '2026-01-02T03:04:05.000Z',
    };

    const threadJson = {
      'id': 'th_1',
      'end_user_id': 'eu_1',
      'subject': 'Billing',
      'status': 'open',
      'created_at': '2026-01-02T03:04:05.000Z',
    };

    test('Message round-trips', () {
      final message = Message.fromJson(messageJson);

      expect(message.sender, MessageSender.member);
      expect(message.memberId, 'mem_1');
      expect(message.toJson(), messageJson);
      expect(Message.fromJson(messageJson), message);
      expect(message.hashCode, Message.fromJson(messageJson).hashCode);
      expect(message.toString(), contains('msg_1'));
    });

    test('Message from an end user has no member id', () {
      final message = Message.fromJson(const {
        'id': 'msg_2',
        'sender': 'end_user',
        'member_id': null,
      });

      expect(message.memberId, isNull);
      expect(message.sender, MessageSender.endUser);
    });

    test('Thread round-trips', () {
      final thread = Thread.fromJson(threadJson);

      expect(thread.status, ThreadStatus.open);
      expect(thread.toJson(), threadJson);
      expect(Thread.fromJson(threadJson), thread);
      expect(thread.hashCode, Thread.fromJson(threadJson).hashCode);
      expect(thread.toString(), contains('Billing'));
    });

    test('ThreadWithMessages carries its messages', () {
      final thread = ThreadWithMessages.fromJson({
        ...threadJson,
        'messages': [messageJson],
      });

      expect(thread.messages, hasLength(1));
      expect(thread.messages.single.body, 'On it.');
      expect(thread.toJson()['messages'], [messageJson]);
      expect(thread.toString(), contains('1 messages'));
    });

    test('a thread with messages never equals a bare thread', () {
      final bare = Thread.fromJson(threadJson);
      final full = ThreadWithMessages.fromJson({
        ...threadJson,
        'messages': const <Object?>[],
      });

      expect(full, isNot(bare));
      expect(bare, isNot(full));
      expect(
        full,
        ThreadWithMessages.fromJson({
          ...threadJson,
          'messages': const <Object?>[],
        }),
      );
      expect(
        full.hashCode,
        ThreadWithMessages.fromJson({
          ...threadJson,
          'messages': const <Object?>[],
        }).hashCode,
      );
    });

    test('threads differ when their messages differ', () {
      final empty = ThreadWithMessages.fromJson(
          {...threadJson, 'messages': const <Object?>[]});
      final one = ThreadWithMessages.fromJson({
        ...threadJson,
        'messages': [messageJson],
      });

      expect(empty, isNot(one));
    });
  });

  group('WaitlistSignup', () {
    const json = {
      'id': 'wl_1',
      'email': 'ada@example.com',
      'status': 'waiting',
      'position': 42,
      'referral_count': 3,
      'referral_code': 'ABC123',
      'token': 'tok_1',
      'source': 'landing',
      'created_at': '2026-01-02T03:04:05.000Z',
      'invited_at': null,
      'joined_at': null,
    };

    test('round-trips', () {
      final signup = WaitlistSignup.fromJson(json);

      expect(signup.status, WaitlistStatus.waiting);
      expect(signup.position, 42);
      expect(signup.invitedAt, isNull);
      expect(signup.toJson(), json);
      expect(WaitlistSignup.fromJson(json), signup);
      expect(signup.hashCode, WaitlistSignup.fromJson(json).hashCode);
      expect(signup.toString(), contains('ada@example.com'));
    });

    test('drops its position once it leaves the queue', () {
      final signup = WaitlistSignup.fromJson({
        ...json,
        'status': 'joined',
        'position': null,
        'joined_at': '2026-02-01T00:00:00.000Z',
      });

      expect(signup.position, isNull);
      expect(signup.status, WaitlistStatus.joined);
      expect(signup.joinedAt, DateTime.utc(2026, 2));
      expect(signup, isNot(WaitlistSignup.fromJson(json)));
    });
  });

  group('beta', () {
    test('BetaProgram round-trips', () {
      const json = {
        'id': 'bp_1',
        'project_id': 'proj_1',
        'name': 'Autumn beta',
        'version': '2.0.0-beta.1',
        'slug': 'autumn-beta',
        'summary': 'New editor',
        'access_url': 'https://example.test/beta',
        'access_instructions': 'Install TestFlight',
        'status': 'active',
        'allow_public_signup': true,
        'feedback_deadline': '2026-09-30T00:00:00.000Z',
        'created_at': '2026-01-02T03:04:05.000Z',
      };

      final program = BetaProgram.fromJson(json);

      expect(program.allowPublicSignup, isTrue);
      expect(program.feedbackDeadline, DateTime.utc(2026, 9, 30));
      expect(program.toJson(), json);
      expect(BetaProgram.fromJson(json), program);
      expect(program.hashCode, BetaProgram.fromJson(json).hashCode);
      expect(program.toString(), contains('Autumn beta'));
      expect(program, isNot(BetaProgram.fromJson(const {})));
    });

    test('BetaTester round-trips', () {
      const json = {
        'id': 'bt_1',
        'beta_program_id': 'bp_1',
        'email': 'ada@example.com',
        'token': 'tok_1',
        'source': 'invite',
        'status': 'joined',
        'end_user_id': 'eu_1',
        'invited_at': '2026-01-02T03:04:05.000Z',
        'joined_at': '2026-01-03T03:04:05.000Z',
      };

      final tester = BetaTester.fromJson(json);

      expect(tester.status, BetaTesterStatus.joined);
      expect(tester.endUserId, 'eu_1');
      expect(tester.toJson(), json);
      expect(BetaTester.fromJson(json), tester);
      expect(tester.hashCode, BetaTester.fromJson(json).hashCode);
      expect(tester.toString(), contains('ada@example.com'));
      expect(tester, isNot(BetaTester.fromJson(const {})));
    });
  });

  group('help center', () {
    test('Article round-trips', () {
      const json = {
        'id': 'art_1',
        'title': 'How to export',
        'slug': 'how-to-export',
        'body': '# Export',
        'excerpt': 'Exporting data',
        'status': 'published',
        'category_id': 'cat_1',
        'published_at': '2026-01-02T03:04:05.000Z',
        'helpful_count': 12,
        'not_helpful_count': 1,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      };

      final article = Article.fromJson(json);

      expect(article.status, ArticleStatus.published);
      expect(article.helpfulCount, 12);
      expect(article.toJson(), json);
      expect(Article.fromJson(json), article);
      expect(article.hashCode, Article.fromJson(json).hashCode);
      expect(article.toString(), contains('how-to-export'));
      expect(article, isNot(Article.fromJson(const {})));
    });

    test('an unpublished article has no category or publish date', () {
      final article = Article.fromJson(const {
        'id': 'art_2',
        'status': 'draft',
        'category_id': null,
        'published_at': null,
      });

      expect(article.categoryId, isNull);
      expect(article.publishedAt, isNull);
      expect(article.status, ArticleStatus.draft);
    });

    test('ArticleSearchResult round-trips', () {
      const json = {
        'id': 'art_1',
        'title': 'How to export',
        'slug': 'how-to-export',
        'category_slug': 'data',
        'category_name': 'Data',
        'snippet': '…how to <em>export</em>…',
        'rank': 0.87,
      };

      final result = ArticleSearchResult.fromJson(json);

      expect(result.rank, 0.87);
      expect(result.categoryName, 'Data');
      expect(result.toJson(), json);
      expect(ArticleSearchResult.fromJson(json), result);
      expect(result.hashCode, ArticleSearchResult.fromJson(json).hashCode);
      expect(result.toString(), contains('art_1'));
    });

    test('ArticleSearchResult tolerates an integer or missing rank', () {
      expect(ArticleSearchResult.fromJson(const {'rank': 1}).rank, 1.0);
      expect(ArticleSearchResult.fromJson(const {}).rank, 0.0);
      expect(
        ArticleSearchResult.fromJson(const {'id': 'a'}),
        isNot(ArticleSearchResult.fromJson(const {'id': 'b'})),
      );
    });

    test('ArticleCategory round-trips', () {
      const json = {
        'id': 'cat_1',
        'name': 'Billing',
        'slug': 'billing',
        'description': 'Invoices and plans',
        'sort_order': 2,
        'created_at': '2026-01-02T03:04:05.000Z',
      };

      final category = ArticleCategory.fromJson(json);

      expect(category.sortOrder, 2);
      expect(category.toJson(), json);
      expect(ArticleCategory.fromJson(json), category);
      expect(category.hashCode, ArticleCategory.fromJson(json).hashCode);
      expect(category.toString(), contains('billing'));
      expect(category, isNot(ArticleCategory.fromJson(const {})));
    });
  });
}
