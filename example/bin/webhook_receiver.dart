// Webhook verification with no framework at all — just dart:io.
//
//   SUPDESK_WEBHOOK_SECRET=whsec_… dart run bin/webhook_receiver.dart
//
// The last section signs a payload the way SupDesk does, so you can exercise
// the handler without waiting for a real delivery.
import 'dart:convert';
import 'dart:io';

import 'package:supdesk/supdesk.dart';

Future<void> main() async {
  final secret = Platform.environment['SUPDESK_WEBHOOK_SECRET'];
  if (secret == null || secret.isEmpty) {
    stderr.writeln('Set SUPDESK_WEBHOOK_SECRET first.');
    exit(1);
  }

  final webhooks = Webhooks(secret);
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
  print('listening on http://${server.address.host}:${server.port}');
  print(_curlHint(webhooks));

  await for (final request in server) {
    if (request.method != 'POST' || request.uri.path != '/webhooks/supdesk') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    // The signature covers these exact bytes. Collect them before anything
    // decodes them — verification is byte-for-byte, and a re-encoded map will
    // never match.
    final rawBytes = await request.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );

    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.first);

    try {
      final event = webhooks.constructEventFromHeaders(rawBytes, headers);
      _handle(event);
      request.response.statusCode = HttpStatus.noContent;
    } on SupDeskSignatureVerificationException catch (error) {
      // Not 500: nothing SupDesk can redeliver will fix a bad signature.
      stderr.writeln('rejected: ${error.message}');
      request.response.statusCode = HttpStatus.badRequest;
    }

    await request.response.close();
  }
}

void _handle(SupDeskWebhookEvent event) {
  print('${event.timestamp?.toIso8601String()}  ${event.type.value}');

  switch (event.type.value) {
    // The waitlist events are the ones SupDesk documents a payload for, so the
    // SDK can decode them into a real model.
    case 'waitlist_signup.created':
    case 'waitlist_signup.invited':
    case 'waitlist_signup.joined':
      final signup = event.asWaitlistSignup();
      print(
        '  ${signup.email} — ${signup.status.value}, '
        'position ${signup.position ?? '—'}',
      );

    // Everything else arrives as an open map, because SupDesk publishes no
    // schema for it. Read what you need and ignore the rest.
    case 'post.status_changed':
      print('  ${event.data['id']}: ${event.data['status']}');
    case 'comment.created':
      print('  comment on ${event.data['post_id']}');
    default:
      print('  ${jsonEncode(event.data)}');
  }
}

/// Builds a `curl` that this server will accept, using the same signing the
/// SDK verifies with.
String _curlHint(Webhooks webhooks) {
  const payload =
      '{"event":"waitlist_signup.joined",'
      '"timestamp":"2026-01-02T03:04:05.000Z",'
      '"project_id":"proj_local",'
      '"data":{"id":"wl_1","email":"ada@example.com","status":"joined",'
      '"position":null,"referral_count":2,"referral_code":"ABC",'
      '"token":"tok","source":"landing"}}';

  return '\ntry it:\n'
      '  curl -X POST http://localhost:8081/webhooks/supdesk \\\n'
      "    -H '$supDeskSignatureHeader: ${webhooks.sign(payload)}' \\\n"
      "    -H 'content-type: application/json' \\\n"
      "    -d '$payload'\n";
}
