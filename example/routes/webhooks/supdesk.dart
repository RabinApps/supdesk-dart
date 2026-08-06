import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:supdesk/supdesk.dart';

final _webhooks = Webhooks(
  Platform.environment['SUPDESK_WEBHOOK_SECRET'] ?? 'whsec_placeholder',
);

/// `POST /webhooks/supdesk` — the endpoint you register in the console.
///
/// `context.request.body()` returns the raw body, which is what the signature
/// covers. `context.request.json()` would parse it for you and break
/// verification, because re-encoding a map does not reproduce the original
/// whitespace or key order.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final rawBody = await context.request.body();

  final SupDeskWebhookEvent event;
  try {
    event = _webhooks.constructEventFromHeaders(
      rawBody,
      context.request.headers,
    );
  } on SupDeskSignatureVerificationException catch (error) {
    // 400, not 500: a bad signature means the caller is not SupDesk, so there
    // is nothing to redeliver.
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': error.message},
    );
  }

  switch (event.type.value) {
    case 'waitlist_signup.joined':
      final signup = event.asWaitlistSignup();
      print('${signup.email} joined after ${signup.referralCount} referrals');
    case 'waitlist_signup.invited':
      print('invited ${event.asWaitlistSignup().email}');
    case 'post.created':
    case 'post.status_changed':
      print('post ${event.data['id']} -> ${event.data['status']}');
    case 'csat_survey.completed':
      print('CSAT ${event.data['score']}');
    default:
      // SupDesk can add an event type at any time. The SDK keeps the raw value
      // rather than failing to parse, so ignoring the unknown ones is safe.
      print('ignoring ${event.type.value}');
  }

  // Acknowledge immediately and do slow work on a queue; a delivery that times
  // out gets retried.
  return Response(statusCode: HttpStatus.noContent);
}
