import '../core/pagination.dart';
import '../core/query.dart';
import '../models/changelog.dart';
import '../models/common.dart';
import '../models/json.dart';
import 'base.dart';

/// Public changelog entries.
class Changelog extends APIResource {
  /// Binds the resource to a transport.
  Changelog(super.client);

  /// `GET /changelog` — the returned [Page] streams every page.
  Future<Page<ChangelogEntry>> list({
    SupDeskLocale? locale,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<ChangelogEntry>(
        '/changelog',
        {'locale': locale?.value, 'limit': limit, 'offset': offset},
        ChangelogEntry.fromJson,
        options: options,
      );

  /// `GET /changelog/:id`
  Future<ChangelogEntry> get(
    String id, {
    SupDeskLocale? locale,
    CallOptions? options,
  }) =>
      requestObject(
        'GET',
        '/changelog/${encodePathSegment(id)}',
        ChangelogEntry.fromJson,
        query: {'locale': locale?.value},
        options: options,
      );

  /// `POST /changelog` — requires a paid plan.
  Future<ChangelogEntry> create({
    required String title,
    String? body,
    List<String>? labels,
    String? version,
    ChangelogStatus? status,
    SupDeskLocale? locale,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/changelog',
        ChangelogEntry.fromJson,
        body: pruneNulls({
          'title': title,
          'body': body,
          'labels': labels,
          'version': version,
          'status': status?.value,
          'locale': locale?.value,
        }),
        options: options,
      );

  /// `PATCH /changelog/:id` — requires a paid plan.
  Future<ChangelogEntry> update(
    String id, {
    String? title,
    String? body,
    List<String>? labels,
    String? version,
    ChangelogStatus? status,
    SupDeskLocale? locale,
    CallOptions? options,
  }) =>
      requestObject(
        'PATCH',
        '/changelog/${encodePathSegment(id)}',
        ChangelogEntry.fromJson,
        body: pruneNulls({
          'title': title,
          'body': body,
          'labels': labels,
          'version': version,
          'status': status?.value,
          'locale': locale?.value,
        }),
        options: options,
      );

  /// `DELETE /changelog/:id` — requires a paid plan.
  Future<void> delete(String id, {CallOptions? options}) => requestEmpty(
        'DELETE',
        '/changelog/${encodePathSegment(id)}',
        options: options,
      );
}
