import '../core/pagination.dart';
import '../core/query.dart';
import '../models/common.dart';
import '../models/json.dart';
import '../models/submissions.dart';
import 'base.dart';

/// Bug reports and feature requests.
class Submissions extends APIResource {
  /// Binds the resource to a transport.
  Submissions(super.client);

  /// `GET /submissions` — the returned [Page] streams every page.
  Future<Page<Submission>> list({
    PostStatus? status,
    SubmissionType? type,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<Submission>(
        '/submissions',
        {
          'status': status?.value,
          'type': type?.value,
          'limit': limit,
          'offset': offset,
        },
        Submission.fromJson,
        options: options,
      );

  /// `GET /submissions/:id`
  Future<Submission> get(String id, {CallOptions? options}) => requestObject(
        'GET',
        '/submissions/${encodePathSegment(id)}',
        Submission.fromJson,
        options: options,
      );

  /// `POST /submissions`
  ///
  /// Counts against the monthly submission quota.
  Future<Submission> create({
    required SubmissionType type,
    required String title,
    required String email,
    String? body,
    String? name,
    SupDeskLocale? locale,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/submissions',
        Submission.fromJson,
        body: pruneNulls({
          'type': type.value,
          'title': title,
          'email': email,
          'body': body,
          'name': name,
          'locale': locale?.value,
        }),
        options: options,
      );
}
