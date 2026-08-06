# supdesk

Dart client for the [SupDesk API](https://docs.supdesk.app/en/api/authentication).

Built on [dio](https://pub.dev/packages/dio), so a `CancelToken`, an interceptor
or a proxy-aware adapter all work the way you already expect.

> [!WARNING]
> **Server-side only. Never ship your API key to an end user.**
>
> A SupDesk API key authenticates as your entire project. Anything that reaches
> a phone or a browser is readable — a compiled Flutter binary can be unpacked,
> and DevTools shows every request a web build makes. Use this SDK from a
> backend you control (a `dart_frog` route, a shelf handler, a cloud function, a
> cron job) and let your app talk to that.
>
> The constructor **throws** in Flutter and web builds. See [Security](#security).

```yaml
dependencies:
  supdesk: ^0.1.0
```

## Quick start

```dart
import 'dart:io';
import 'package:supdesk/supdesk.dart';

final supdesk = SupDesk(apiKey: Platform.environment['SUPDESK_API_KEY']!);

// Auto-pages: the stream walks every page for you.
final page = await supdesk.submissions.list(status: PostStatus.open);
await for (final submission in page.autoPaging()) {
  print(submission.title);
}

await supdesk.submissions.create(
  type: SubmissionType.bug,
  title: 'Export button does nothing',
  email: 'user@example.com',
  body: 'Clicking Export on the reports page has no effect.',
);
```

API keys come from **Workspace Settings → API Keys** in the SupDesk console and
are scoped to a single project. Reads work on every plan; **writes (`POST`,
`PATCH`, `DELETE`) require a paid plan** and otherwise raise a
`ForbiddenException`.

## Security

**The API key is a server-side secret.** It is project-scoped, and on a paid
plan it can create, edit and delete submissions, feedback, changelog entries,
help center articles, message threads, waitlist signups and beta programs — and
read every end-user email address in your project. SupDesk has no browser-safe
publishable key.

So the client refuses to start anywhere an end user could read it:

```dart
// In a Flutter widget, or anything compiled for the web:
SupDesk(apiKey: 'sd_live_…');
// → SupDeskConfigurationException: SupDesk is a server-side SDK and was
//   constructed in a Flutter or web build. …
```

Detection is a compile-time constant (`dart.library.ui` for Flutter,
`dart.library.js_interop` for web), so it costs nothing at runtime and cannot be
tricked by a release build. If you hit this error, the key is already in your
app bundle — **rotate it** in Workspace Settings → API Keys, then move the call
behind your own endpoint:

```dart
// A dart_frog route — runs on your server.
Future<Response> onRequest(RequestContext context) async {
  final body = await context.request.json() as Map<String, dynamic>;
  // Validate and rate-limit here: this endpoint is public, your key is not.
  await supdesk.feedback.create(
    title: body['title'] as String,
    email: body['email'] as String,
  );
  return Response.json(body: {'ok': true});
}
```

`dangerouslyAllowClientSide: true` bypasses the check. It exists for cases where
the key genuinely is not a secret — an internal desktop tool behind SSO, or a
test harness pointed at a stub `baseUrl` — and is named to make its use
conspicuous in review.

Two related habits worth keeping: give each environment its own key so one can
be revoked without downtime elsewhere, and store the **webhook signing secret**
server-side too, since it is what proves a delivery actually came from SupDesk.

## Client options

```dart
final supdesk = SupDesk(
  apiKey: 'sd_live_…',
  baseUrl: 'https://api.supdesk.app/v1', // default
  dio: myDio,                            // default: one the client owns
  timeout: const Duration(seconds: 30),  // Duration.zero disables
  maxRetries: 2,                         // retries after the first attempt
  retryUnsafeMethods: false,
  defaultHeaders: {'x-app': 'my-service'},
  dangerouslyAllowClientSide: false,     // default; see Security
);
```

Every method also takes `options: CallOptions(timeout: …, headers: …,
cancelToken: …)` as a final named argument.

Call `supdesk.close()` when you are done. It disposes the `Dio` the client
created, and leaves an injected one alone — that instance is yours.

## Resources

| Accessor            | Methods                                              |
| ------------------- | ---------------------------------------------------- |
| `submissions`       | `list` `get` `create`                                |
| `feedback`          | `list` `get` `create`                                |
| `changelog`         | `list` `get` `create` `update` `delete`              |
| `messages`          | `list` `get` `create` `update` `delete` `addMessage` |
| `waitlist`          | `list` `get` `create` `update` `delete`              |
| `beta.programs`     | `list` `get` `create` `update` `delete`              |
| `beta.testers`      | `list` `get` `create` `delete`                       |
| `articles`          | `list` `search` `get` `create` `update` `delete`     |
| `articleCategories` | `list` `get` `create` `update` `delete`              |

## Pagination

`list()` returns a `Page`, which is both the current page and a stream over
everything after it.

```dart
final page = await supdesk.articles.list(status: ArticleStatus.published);

page.data;            // just this page
page.pagination;      // limit, offset, hasMore
page.hasNextPage();
await page.getNextPage();

await for (final article in page.autoPaging()) { /* every page */ }
await page.toList();  // everything, in memory
```

`articles.search()` is the exception — it returns a plain ranked list, not a
page.

## Status values

Statuses, types and locales are Dart 3 extension types over `String`, not
enums. The documented values autocomplete, and a value SupDesk adds later still
parses instead of crashing a client that predates it.

```dart
PostStatus.inProgress.value;      // 'in_progress'
submission.status == PostStatus.open;
const PostStatus('under_review'); // whatever the server sends
```

## Errors

Every failure is a `SupDeskException`, so one `catch` covers the lot while
`on`-clauses still narrow to the specific case. The base class is `sealed`, so a
`switch` over it is exhaustive.

```dart
try {
  await supdesk.articles.create(title: 'How to export');
} on ForbiddenException {
  // Valid key, but writes need a paid plan.
} on LimitReachedException {
  // Monthly submission quota exhausted.
} on SupDeskException catch (error) {
  print(error.message);
}
```

| Class                       | Status | Code              |
| --------------------------- | ------ | ----------------- |
| `InvalidRequestException`   | 400    | `invalid_request` |
| `UnauthorizedException`     | 401    | `unauthorized`    |
| `ForbiddenException`        | 403    | `forbidden`       |
| `NotFoundException`         | 404    | `not_found`       |
| `RateLimitedException`      | 429    | `rate_limited`    |
| `LimitReachedException`     | 429    | `limit_reached`   |
| `InternalServerException`   | 5xx    | `internal_error`  |

Plus `SupDeskConnectionException`, `SupDeskTimeoutException`,
`RequestTooLargeException` (the API caps requests at 1 MB, checked before
sending), `SupDeskConfigurationException` and
`SupDeskSignatureVerificationException`.

Cancellation is the one thing that is *not* wrapped: cancelling a `CancelToken`
raises dio's own `DioException` with `DioExceptionType.cancel`, because that
result is the caller's to observe, not a SupDesk failure.

## Retries

The client retries with exponential backoff and jitter, honouring `Retry-After`
when a proxy supplies one. Two behaviours are worth knowing about:

- **`limit_reached` is never retried.** It shares HTTP 429 with `rate_limited`,
  but a monthly quota will not clear inside a backoff window — retrying just
  burns more of your 120-requests-per-minute budget. The two are told apart by
  `code`, not status.
- **`POST` is not replayed** on connection errors or 5xx by default. SupDesk has
  no idempotency key, and `submissions.create` / `feedback.create` are metered,
  so a request that failed *after* the server accepted it would double-charge
  your quota and file the end user's ticket twice. A 429 `rate_limited` is still
  retried on any method, because the server states it did not process the
  request. Opt in with `retryUnsafeMethods: true`.

## Webhooks

```dart
import 'package:supdesk/supdesk.dart';

final webhooks = Webhooks(webhookSigningSecret);

Future<Response> onRequest(RequestContext context) async {
  final event = webhooks.constructEventFromHeaders(
    await context.request.body(), // the raw body, not a decoded map
    context.request.headers,
  );

  switch (event.type.value) {
    case 'waitlist_signup.joined':
      print(event.asWaitlistSignup().email);
    case 'post.status_changed':
      print(event.data['status']);
  }

  return Response(statusCode: 204);
}
```

> **Pass the raw body.** The signature covers the exact bytes SupDesk sent, so a
> framework that decodes JSON for you breaks verification — `jsonEncode` will
> not reproduce the original whitespace and key order. Capture the raw body
> first.

Lower-level helpers: `verifyWebhookSignature(...)` returns a bool,
`constructEvent(...)` throws on mismatch, and `computeWebhookSignature(...)`
builds fixtures. Comparison is constant-time.

## Contributing

```bash
dart pub get
dart test
dart run coverage:test_with_coverage && dart run tool/check_coverage.dart 80
dart analyze --fatal-infos
dart format .
```

### Releasing

1. Bump `version` in `pubspec.yaml` **and** `packageVersion` in
   `lib/src/version.dart` (CI checks they agree — the version rides in the
   `user-agent` of every request), and add a `CHANGELOG.md` entry.
2. Tag `vX.Y.Z` and push it. `.github/workflows/publish.yml` re-runs the whole
   suite, checks the tag against the pubspec, and publishes over OIDC — there is
   no `PUB_TOKEN` secret to leak.

The first release is manual: run `dart pub publish` locally, then enable
**Automated publishing** on the package's Admin tab on pub.dev (GitHub Actions,
repository `RabinApps/supdesk-dart`, tag pattern `v{{version}}`). That page only
exists once the package does.

## License

MIT
