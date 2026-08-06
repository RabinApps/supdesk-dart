import 'package:dio/dio.dart' show Dio;
import 'package:meta/meta.dart';

import 'core/errors.dart';
import 'core/http.dart';
import 'core/retry.dart';
import 'core/runtime.dart';
import 'resources/article_categories.dart';
import 'resources/articles.dart';
import 'resources/beta.dart';
import 'resources/changelog.dart';
import 'resources/feedback.dart';
import 'resources/messages.dart';
import 'resources/submissions.dart';
import 'resources/waitlist.dart';

/// The SupDesk API client.
///
/// **Server-side only.** A SupDesk API key grants project-wide access, so it
/// must stay on a machine you control — a backend, a `dart_frog` route, a cloud
/// function, a cron job. Constructing this in a Flutter app or a web build
/// throws; see [SupDesk.new]'s `dangerouslyAllowClientSide`.
///
/// ```dart
/// final supdesk = SupDesk(apiKey: Platform.environment['SUPDESK_API_KEY']!);
///
/// final page = await supdesk.submissions.list(status: PostStatus.open);
/// await for (final submission in page.autoPaging()) {
///   print(submission.title);
/// }
/// ```
class SupDesk {
  /// Creates a client for one project-scoped API key.
  ///
  /// [apiKey] comes from Workspace Settings → API Keys in the SupDesk console
  /// and looks like `sd_live_…`. Read it from an environment variable or a
  /// secret manager — never from a compiled-in constant.
  ///
  /// Pass [dio] to supply a pre-configured client (interceptors, a proxy, a
  /// stub adapter in tests); the caller keeps ownership and [close] leaves it
  /// open.
  ///
  /// [dangerouslyAllowClientSide] disables the guard that refuses to construct
  /// the client in a Flutter or web build. It exists for cases where the key
  /// genuinely is not a secret — an internal desktop tool on a trusted network,
  /// or a test harness pointed at a stub [baseUrl] — and is named to make its
  /// use conspicuous in review.
  factory SupDesk({
    required String apiKey,
    String baseUrl = defaultBaseUrl,
    Dio? dio,
    Duration timeout = defaultTimeout,
    int maxRetries = defaultMaxRetries,
    bool retryUnsafeMethods = false,
    Map<String, String> defaultHeaders = const {},
    bool dangerouslyAllowClientSide = false,
    @visibleForTesting bool Function()? isClientSideRuntime,
  }) {
    _guard(
      apiKey: apiKey,
      isClientSide: (isClientSideRuntime ?? defaultIsClientSideRuntime)(),
      allowClientSide: dangerouslyAllowClientSide,
    );

    return SupDesk._(
      SupDeskHttpClient(
        apiKey: apiKey,
        baseUrl: baseUrl,
        dio: dio,
        timeout: timeout,
        maxRetries: maxRetries,
        retryUnsafeMethods: retryUnsafeMethods,
        defaultHeaders: defaultHeaders,
      ),
    );
  }

  SupDesk._(this.http)
      : submissions = Submissions(http),
        feedback = FeedbackResource(http),
        changelog = Changelog(http),
        messages = Messages(http),
        waitlist = Waitlist(http),
        beta = Beta(http),
        articles = Articles(http),
        articleCategories = ArticleCategories(http);

  /// Bug reports and feature requests.
  final Submissions submissions;

  /// General product feedback.
  final FeedbackResource feedback;

  /// Public changelog entries.
  final Changelog changelog;

  /// Support conversations.
  final Messages messages;

  /// Waitlist signups.
  final Waitlist waitlist;

  /// Beta programs and their testers.
  final Beta beta;

  /// Help center articles.
  final Articles articles;

  /// Help center categories.
  final ArticleCategories articleCategories;

  /// The transport, exposed for advanced use and for calling routes this SDK
  /// does not model yet.
  final SupDeskHttpClient http;

  /// Releases the underlying dio instance, unless one was injected.
  void close() => http.close();
}

/// Validates construction inputs before any resource is built.
///
/// Failing here rather than on first request means a misconfigured client is a
/// startup error, not an error buried in one code path.
void _guard({
  required String apiKey,
  required bool isClientSide,
  required bool allowClientSide,
}) {
  if (apiKey.isEmpty) {
    throw const SupDeskConfigurationException(
      'A SupDesk API key is required. Create one under Workspace Settings → '
      'API Keys.',
    );
  }

  // Fail loudly rather than let a project-wide key ship to end users. By the
  // time this runs in an app or a browser the key is already in the bundle, so
  // the error names the remedy: move the call server-side and rotate the key.
  if (isClientSide && !allowClientSide) {
    throw const SupDeskConfigurationException(
      'SupDesk is a server-side SDK and was constructed in a Flutter or web '
      'build. Your API key grants project-wide access, and anything shipped to '
      'an end user is readable — assume a key already bundled this way is '
      'compromised and rotate it in Workspace Settings → API Keys. Call '
      'SupDesk from a backend you control and have the app talk to that '
      'instead. If the key genuinely is not a secret here, pass '
      '`dangerouslyAllowClientSide: true`.',
    );
  }
}
