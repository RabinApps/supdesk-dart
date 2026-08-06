/// A server-side Dart client for the [SupDesk API](https://docs.supdesk.app).
///
/// ```dart
/// final supdesk = SupDesk(apiKey: Platform.environment['SUPDESK_API_KEY']!);
///
/// await supdesk.submissions.create(
///   type: SubmissionType.bug,
///   title: 'Export button does nothing',
///   email: 'user@example.com',
///   body: 'Clicking Export on the reports page has no effect.',
/// );
/// ```
///
/// **Never ship your API key to an end user.** A SupDesk key authenticates as
/// your entire project, so the client refuses to construct itself in a Flutter
/// or web build. Call it from a backend you control and have your app talk to
/// that.
library;

// Re-exported so callers can hold a CancelToken, configure their own Dio, and
// catch the cancellation this SDK deliberately passes through, without taking
// a direct dependency on dio themselves.
export 'package:dio/dio.dart'
    show CancelToken, Dio, DioException, DioExceptionType;

export 'src/client.dart';
export 'src/core/errors.dart';
export 'src/core/http.dart'
    show
        SupDeskHttpClient,
        defaultBaseUrl,
        defaultTimeout,
        maxRequestBytes,
        parseResponse;
export 'src/core/pagination.dart';
export 'src/core/retry.dart'
    show
        backoffDelay,
        baseRetryDelay,
        defaultMaxRetries,
        maxRetryDelay,
        parseRetryAfter,
        shouldRetry;
export 'src/core/runtime.dart';
export 'src/models/beta.dart';
export 'src/models/changelog.dart';
export 'src/models/common.dart';
export 'src/models/feedback.dart';
export 'src/models/help_center.dart';
export 'src/models/messages.dart';
export 'src/models/submissions.dart';
export 'src/models/waitlist.dart';
export 'src/resources/article_categories.dart';
export 'src/resources/articles.dart';
export 'src/resources/base.dart' show APIResource, CallOptions;
export 'src/resources/beta.dart';
export 'src/resources/changelog.dart';
export 'src/resources/feedback.dart';
export 'src/resources/messages.dart';
export 'src/resources/submissions.dart';
export 'src/resources/waitlist.dart';
export 'src/version.dart';
export 'src/webhooks.dart';
