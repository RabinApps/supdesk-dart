import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:supdesk/supdesk.dart';

/// `POST /feedback` — the endpoint your app calls instead of SupDesk.
///
/// This route is public and the API key is not, which is the whole point of
/// putting it here: validate and rate-limit at this boundary, because every
/// call it forwards is spent from your monthly quota.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await context.request.json();
  if (body is! Map<String, dynamic>) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': 'expected a JSON object'},
    );
  }

  final title = body['title'];
  final email = body['email'];
  if (title is! String || email is! String) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'error': '`title` and `email` are required'},
    );
  }

  final feedback = await context.read<SupDesk>().feedback.create(
    title: title,
    email: email,
    body: body['body'] as String?,
    name: body['name'] as String?,
    locale: SupDeskLocale.en,
  );

  return Response.json(
    statusCode: HttpStatus.created,
    body: {'id': feedback.id, 'status': feedback.status.value},
  );
}
