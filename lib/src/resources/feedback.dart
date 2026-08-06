import '../core/pagination.dart';
import '../core/query.dart';
import '../models/common.dart';
import '../models/feedback.dart';
import '../models/json.dart';
import 'base.dart';

/// General product feedback, separate from bug and feature submissions.
class FeedbackResource extends APIResource {
  /// Binds the resource to a transport.
  FeedbackResource(super.client);

  /// `GET /feedback` — the returned [Page] streams every page.
  Future<Page<Feedback>> list({
    PostStatus? status,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<Feedback>(
        '/feedback',
        {'status': status?.value, 'limit': limit, 'offset': offset},
        Feedback.fromJson,
        options: options,
      );

  /// `GET /feedback/:id`
  Future<Feedback> get(String id, {CallOptions? options}) => requestObject(
        'GET',
        '/feedback/${encodePathSegment(id)}',
        Feedback.fromJson,
        options: options,
      );

  /// `POST /feedback`
  ///
  /// Metered against the same monthly submission quota as
  /// `submissions.create`, and requires a paid plan.
  Future<Feedback> create({
    required String title,
    required String email,
    String? body,
    String? name,
    SupDeskLocale? locale,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/feedback',
        Feedback.fromJson,
        body: pruneNulls({
          'title': title,
          'email': email,
          'body': body,
          'name': name,
          'locale': locale?.value,
        }),
        options: options,
      );
}
