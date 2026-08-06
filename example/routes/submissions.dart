import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:supdesk/supdesk.dart';

/// `GET /submissions?status=open&type=bug` — a read-through to SupDesk.
///
/// Shows both halves of pagination: one page for a normal request, and the
/// auto-paging stream behind `?all=true` for a small export.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final params = context.request.uri.queryParameters;
  final supdesk = context.read<SupDesk>();

  final page = await supdesk.submissions.list(
    // Unknown values are passed straight through; SupDesk validates them and
    // answers 400 `invalid_request` if they are wrong.
    status: params['status'] == null ? null : PostStatus(params['status']!),
    type: params['type'] == null ? null : SubmissionType(params['type']!),
    limit: int.tryParse(params['limit'] ?? ''),
  );

  // `autoPaging()` issues one request per page, so only reach for it when the
  // result set is genuinely small — an export, not a page of UI.
  final submissions = params['all'] == 'true' ? await page.toList() : page.data;

  return Response.json(
    body: {
      'data': [
        for (final submission in submissions)
          {
            'id': submission.id,
            'type': submission.type.value,
            'title': submission.title,
            'status': submission.status.value,
            'created_at': submission.createdAt?.toIso8601String(),
          },
      ],
      'has_more': params['all'] == 'true' ? false : page.hasNextPage(),
    },
  );
}
