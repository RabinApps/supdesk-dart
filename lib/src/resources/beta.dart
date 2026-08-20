import '../core/http.dart';
import '../core/pagination.dart';
import '../core/query.dart';
import '../models/beta.dart';
import '../models/json.dart';
import 'base.dart';

/// `/beta/programs`
class BetaPrograms extends APIResource {
  /// Binds the resource to a transport.
  BetaPrograms(super.client);

  /// `GET /beta/programs` — the returned [Page] streams every page.
  Future<Page<BetaProgram>> list({
    String? status,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<BetaProgram>(
        '/beta/programs',
        {'status': status, 'limit': limit, 'offset': offset},
        BetaProgram.fromJson,
        options: options,
      );

  /// `GET /beta/programs/:id`
  Future<BetaProgram> get(String id, {CallOptions? options}) => requestObject(
        'GET',
        '/beta/programs/${encodePathSegment(id)}',
        BetaProgram.fromJson,
        options: options,
      );

  /// `POST /beta/programs`
  Future<BetaProgram> create({
    required String name,
    String? version,
    String? summary,
    String? accessUrl,
    String? accessInstructions,
    String? status,
    bool? allowPublicSignup,
    DateTime? feedbackDeadline,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/beta/programs',
        BetaProgram.fromJson,
        body: pruneNulls({
          'name': name,
          'version': version,
          'summary': summary,
          'access_url': accessUrl,
          'access_instructions': accessInstructions,
          'status': status,
          'allow_public_signup': allowPublicSignup,
          'feedback_deadline': feedbackDeadline?.toIso8601String(),
        }),
        options: options,
      );

  /// `PATCH /beta/programs/:id`
  Future<BetaProgram> update(
    String id, {
    String? name,
    String? version,
    String? summary,
    String? accessUrl,
    String? accessInstructions,
    String? status,
    bool? allowPublicSignup,
    DateTime? feedbackDeadline,
    CallOptions? options,
  }) =>
      requestObject(
        'PATCH',
        '/beta/programs/${encodePathSegment(id)}',
        BetaProgram.fromJson,
        body: pruneNulls({
          'name': name,
          'version': version,
          'summary': summary,
          'access_url': accessUrl,
          'access_instructions': accessInstructions,
          'status': status,
          'allow_public_signup': allowPublicSignup,
          'feedback_deadline': feedbackDeadline?.toIso8601String(),
        }),
        options: options,
      );

  /// `DELETE /beta/programs/:id`
  Future<void> delete(String id, {CallOptions? options}) => requestEmpty(
        'DELETE',
        '/beta/programs/${encodePathSegment(id)}',
        options: options,
      );
}

/// `/beta/programs/:programId/testers`
///
/// Testers are nested under a program, so every method takes the program id
/// first. SupDesk documents no update endpoint for testers.
class BetaTesters extends APIResource {
  /// Binds the resource to a transport.
  BetaTesters(super.client);

  /// `GET /beta/programs/:programId/testers` — the returned [Page] streams
  /// every page.
  Future<Page<BetaTester>> list(
    String programId, {
    String? status,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<BetaTester>(
        _path(programId),
        {'status': status, 'limit': limit, 'offset': offset},
        BetaTester.fromJson,
        options: options,
      );

  /// `GET /beta/programs/:programId/testers/:id`
  Future<BetaTester> get(
    String programId,
    String id, {
    CallOptions? options,
  }) =>
      requestObject(
        'GET',
        '${_path(programId)}/${encodePathSegment(id)}',
        BetaTester.fromJson,
        options: options,
      );

  /// `POST /beta/programs/:programId/testers`
  Future<BetaTester> create(
    String programId, {
    required String email,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        _path(programId),
        BetaTester.fromJson,
        body: {'email': email},
        options: options,
      );

  /// `DELETE /beta/programs/:programId/testers/:id`
  Future<void> delete(
    String programId,
    String id, {
    CallOptions? options,
  }) =>
      requestEmpty(
        'DELETE',
        '${_path(programId)}/${encodePathSegment(id)}',
        options: options,
      );

  String _path(String programId) =>
      '/beta/programs/${encodePathSegment(programId)}/testers';
}

/// Groups the beta programs and testers resources.
class Beta {
  /// Creates the group and its two resources.
  Beta(SupDeskHttpClient client)
      : programs = BetaPrograms(client),
        testers = BetaTesters(client);

  /// Beta programs.
  final BetaPrograms programs;

  /// Testers within a program.
  final BetaTesters testers;
}
