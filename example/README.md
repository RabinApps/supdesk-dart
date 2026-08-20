# supdesk examples

Runnable examples for [`package:supdesk`](https://pub.dev/packages/supdesk).
This directory is its own package with a path dependency on the parent, so the
examples always run against the working tree.

```bash
cd example
dart pub get
```

Every example reads its credentials from the environment. Both are secrets, and
neither should ever reach a shipped app:

```bash
export SUPDESK_API_KEY=sd_live_…       # Workspace Settings → API Keys
export SUPDESK_WEBHOOK_SECRET=whsec_…  # the webhook's signing secret
```

Reads and writes both work on every plan, so every example here runs on Free.
The only cap is creation: `submissions.create` and `feedback.create` are metered
against your monthly quota — 250 on Free — and raise a `LimitReachedException`
once it is spent.

## Servers

| File | What it shows |
| --- | --- |
| [`bin/shelf_server.dart`](bin/shelf_server.dart) | A shelf server with a feedback intake endpoint, a webhook receiver, and one middleware that maps every SupDesk failure to an HTTP status |
| [`routes/`](routes) | The same shape in dart_frog: a `provider` for the client, per-route handlers, and a webhook route that reads the raw body |
| [`bin/webhook_receiver.dart`](bin/webhook_receiver.dart) | Signature verification with no framework at all — just `dart:io`. Prints a signed `curl` you can paste to test it |

```bash
dart run bin/shelf_server.dart          # http://localhost:8080
dart run bin/webhook_receiver.dart      # http://localhost:8081
```

For dart_frog, from this directory:

```bash
dart pub global activate dart_frog_cli
dart_frog dev                           # http://localhost:8080
```

## Scripts

| File | What it shows |
| --- | --- |
| [`supdesk_example.dart`](supdesk_example.dart) | The two-minute tour: list, search, create, catch |
| [`bin/pagination.dart`](bin/pagination.dart) | One page, page-by-page, `autoPaging()` as a stream, `toList()`, and composing stream operators |
| [`bin/resilience.dart`](bin/resilience.dart) | A custom `Dio` with interceptors, per-call timeouts, `CancelToken`, retry configuration, and the full exception hierarchy |
| [`bin/help_center.dart`](bin/help_center.dart) | Category → draft → publish → search → delete |
| [`bin/support_inbox.dart`](bin/support_inbox.dart) | Threads, replies, and closing a conversation |
| [`bin/waitlist_and_beta.dart`](bin/waitlist_and_beta.dart) | Inviting from the queue, then enrolling the same people as beta testers |

```bash
dart run bin/pagination.dart
```

## The one rule for webhooks

Verify against the **raw** request body. The signature covers the exact bytes
SupDesk sent, and re-encoding a decoded map will not reproduce the original
whitespace or key order:

| Framework | Raw body | Decoded — breaks verification |
| --- | --- | --- |
| shelf | `await request.readAsString()` | `jsonDecode(...)` then re-encode |
| dart_frog | `await context.request.body()` | `await context.request.json()` |
| `dart:io` | fold the `HttpRequest` stream to bytes | `utf8.decoder.bind(...)` then decode |

## Why a server at all

A SupDesk API key authenticates as your entire project — it can read every
end-user email address, see posts hidden from the public portal, and delete
anything. There is no browser-safe publishable key, so the client throws if it is
constructed in a Flutter or web build.

That is what these servers are for: your app calls **your** endpoint, and your
endpoint holds the key. Validate and rate-limit there, since the endpoint is
public even though the key is not.
