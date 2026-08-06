import '../core/pagination.dart';
import '../core/query.dart';
import '../models/common.dart';
import '../models/json.dart';
import '../models/waitlist.dart';
import 'base.dart';

/// Waitlist signups.
///
/// Signups are the only sub-resource, so the methods sit flat.
class Waitlist extends APIResource {
  /// Binds the resource to a transport.
  Waitlist(super.client);

  /// `GET /waitlist/signups` — the returned [Page] streams every page.
  ///
  /// Note the API's default page size is 25 here, not 20.
  Future<Page<WaitlistSignup>> list({
    String? search,
    WaitlistStatus? status,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<WaitlistSignup>(
        '/waitlist/signups',
        {
          'search': search,
          'status': status?.value,
          'limit': limit,
          'offset': offset,
        },
        WaitlistSignup.fromJson,
        options: options,
      );

  /// `GET /waitlist/signups/:id`
  Future<WaitlistSignup> get(String id, {CallOptions? options}) =>
      requestObject(
        'GET',
        '/waitlist/signups/${encodePathSegment(id)}',
        WaitlistSignup.fromJson,
        options: options,
      );

  /// `POST /waitlist/signups` — requires a paid plan.
  Future<WaitlistSignup> create({
    required String email,
    String? referralCode,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/waitlist/signups',
        WaitlistSignup.fromJson,
        body: pruneNulls({'email': email, 'referral_code': referralCode}),
        options: options,
      );

  /// `PATCH /waitlist/signups/:id` — moves a signup between waiting, invited
  /// and joined. Requires a paid plan.
  Future<WaitlistSignup> update(
    String id, {
    required WaitlistStatus status,
    CallOptions? options,
  }) =>
      requestObject(
        'PATCH',
        '/waitlist/signups/${encodePathSegment(id)}',
        WaitlistSignup.fromJson,
        body: {'status': status.value},
        options: options,
      );

  /// `DELETE /waitlist/signups/:id` — requires a paid plan.
  Future<void> delete(String id, {CallOptions? options}) => requestEmpty(
        'DELETE',
        '/waitlist/signups/${encodePathSegment(id)}',
        options: options,
      );
}
