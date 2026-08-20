// A shelf server that fronts SupDesk.
//
//   SUPDESK_API_KEY=sd_live_… SUPDESK_WEBHOOK_SECRET=whsec_… \
//     dart run bin/shelf_server.dart
//
// Two endpoints, both of which exist because the API key must never leave the
// server:
//
//   POST /feedback          your app posts here; this handler holds the key
//   POST /webhooks/supdesk  SupDesk posts here; this handler verifies the
//                           signature over the raw body
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:supdesk/supdesk.dart';

late final SupDesk supdesk;
late final Webhooks webhooks;

Future<void> main() async {
  supdesk = SupDesk(apiKey: _env('SUPDESK_API_KEY'));
  webhooks = Webhooks(_env('SUPDESK_WEBHOOK_SECRET'));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_catchSupDeskErrors)
      .addHandler(_route);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('listening on http://${server.address.host}:${server.port}');
}

Future<Response> _route(Request request) async {
  final path = '/${request.url.path}';

  return switch ((request.method, path)) {
    ('POST', '/feedback') => _createFeedback(request),
    ('POST', '/webhooks/supdesk') => _receiveWebhook(request),
    ('GET', '/articles') => _searchArticles(request),
    _ => Response.notFound('no route for ${request.method} $path'),
  };
}

/// Your app posts here instead of talking to SupDesk directly.
///
/// This endpoint is public, so it — not SupDesk — is where you validate input
/// and rate-limit. Everything it forwards is spent from your monthly quota.
Future<Response> _createFeedback(Request request) async {
  final body = jsonDecode(await request.readAsString());
  if (body is! Map<String, dynamic>) {
    return Response.badRequest(body: 'expected a JSON object');
  }

  final title = body['title'];
  final email = body['email'];
  if (title is! String || email is! String) {
    return Response.badRequest(body: '`title` and `email` are required');
  }

  final feedback = await supdesk.feedback.create(
    title: title,
    email: email,
    body: body['body'] as String?,
    name: body['name'] as String?,
  );

  return Response.ok(
    jsonEncode({'id': feedback.id, 'status': feedback.status.value}),
    headers: {'content-type': 'application/json'},
  );
}

/// SupDesk posts here.
///
/// `readAsString()` hands back the bytes SupDesk actually sent, which is what
/// the signature covers. Decoding to a map first and re-encoding it would never
/// verify: `jsonEncode` does not reproduce the original whitespace or key
/// order.
Future<Response> _receiveWebhook(Request request) async {
  final rawBody = await request.readAsString();

  final SupDeskWebhookEvent event;
  try {
    event = webhooks.constructEventFromHeaders(rawBody, request.headers);
  } on SupDeskSignatureVerificationException catch (error) {
    // 400, not 500: a bad signature means the sender is not SupDesk, and
    // SupDesk should not be asked to redeliver it.
    return Response.badRequest(body: error.message);
  }

  switch (event.type.value) {
    case 'waitlist_signup.joined':
      final signup = event.asWaitlistSignup();
      print('${signup.email} joined from ${signup.source}');
    case 'post.status_changed':
      print('post ${event.data['id']} is now ${event.data['status']}');
    case 'message.created':
      print('new message in thread ${event.data['thread_id']}');
    default:
      // Unknown types are expected: SupDesk can add one at any time, and this
      // SDK keeps the raw value rather than failing to parse it.
      print('ignoring ${event.type.value}');
  }

  // Acknowledge fast. Do the slow work on a queue, or SupDesk will time the
  // delivery out and retry it.
  return Response(204);
}

Future<Response> _searchArticles(Request request) async {
  final query = request.url.queryParameters['q'];
  if (query == null || query.isEmpty) {
    return Response.badRequest(body: 'pass ?q=');
  }

  final hits = await supdesk.articles.search(query, limit: 5);

  return Response.ok(
    jsonEncode([
      for (final hit in hits)
        {'id': hit.id, 'title': hit.title, 'slug': hit.slug, 'rank': hit.rank},
    ]),
    headers: {'content-type': 'application/json'},
  );
}

/// Turns SupDesk failures into sensible HTTP responses.
///
/// Every failure this SDK raises shares one base class, so a single middleware
/// covers the lot while the specific cases still get their own status.
Handler _catchSupDeskErrors(Handler inner) => (request) async {
  try {
    return await inner(request);
  } on LimitReachedException {
    // The monthly quota is gone; backing off will not help.
    return Response(503, body: 'SupDesk quota exhausted.');
  } on RateLimitedException {
    return Response(429, body: 'Slow down.');
  } on SupDeskApiException catch (error) {
    return Response(
      502,
      body: 'SupDesk said ${error.statusCode} ${error.code}.',
    );
  } on SupDeskException catch (error) {
    return Response(502, body: error.message);
  }
};

String _env(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    stderr.writeln('Set $name first.');
    exit(1);
  }
  return value;
}
