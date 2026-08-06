import 'common.dart';
import 'json.dart';

/// A beta program end users can be invited into.
class BetaProgram {
  /// Creates a beta program.
  const BetaProgram({
    required this.id,
    required this.projectId,
    required this.name,
    required this.version,
    required this.slug,
    required this.summary,
    required this.accessUrl,
    required this.accessInstructions,
    required this.status,
    required this.allowPublicSignup,
    this.feedbackDeadline,
    this.createdAt,
  });

  /// Reads a beta program object.
  factory BetaProgram.fromJson(Map<String, dynamic> json) => BetaProgram(
        id: stringOrEmpty(json['id']),
        projectId: stringOrEmpty(json['project_id']),
        name: stringOrEmpty(json['name']),
        version: stringOrEmpty(json['version']),
        slug: stringOrEmpty(json['slug']),
        summary: stringOrEmpty(json['summary']),
        accessUrl: stringOrEmpty(json['access_url']),
        accessInstructions: stringOrEmpty(json['access_instructions']),
        status: stringOrEmpty(json['status']),
        allowPublicSignup: boolOrFalse(json['allow_public_signup']),
        feedbackDeadline: dateTimeOrNull(json['feedback_deadline']),
        createdAt: dateTimeOrNull(json['created_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// The project this program belongs to.
  final String projectId;

  /// Display name.
  final String name;

  /// Build or release version under test.
  final String version;

  /// URL-safe name.
  final String slug;

  /// Short description shown to testers.
  final String summary;

  /// Where testers get the build.
  final String accessUrl;

  /// How testers install or enrol.
  final String accessInstructions;

  /// Program lifecycle state. SupDesk documents no fixed set, so this stays a
  /// plain string.
  final String status;

  /// Whether anyone can sign up without an invitation.
  final bool allowPublicSignup;

  /// When feedback closes, if a deadline was set.
  final DateTime? feedbackDeadline;

  /// When the program was created.
  final DateTime? createdAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'version': version,
        'slug': slug,
        'summary': summary,
        'access_url': accessUrl,
        'access_instructions': accessInstructions,
        'status': status,
        'allow_public_signup': allowPublicSignup,
        'feedback_deadline': feedbackDeadline?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  String toString() =>
      'BetaProgram(id: $id, name: $name, version: $version, status: $status)';

  @override
  bool operator ==(Object other) =>
      other is BetaProgram &&
      other.id == id &&
      other.projectId == projectId &&
      other.name == name &&
      other.version == version &&
      other.slug == slug &&
      other.summary == summary &&
      other.accessUrl == accessUrl &&
      other.accessInstructions == accessInstructions &&
      other.status == status &&
      other.allowPublicSignup == allowPublicSignup &&
      other.feedbackDeadline == feedbackDeadline &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        projectId,
        name,
        version,
        slug,
        summary,
        accessUrl,
        accessInstructions,
        status,
        allowPublicSignup,
        feedbackDeadline,
        createdAt,
      );
}

/// Someone invited to, or participating in, a beta program.
class BetaTester {
  /// Creates a beta tester.
  const BetaTester({
    required this.id,
    required this.betaProgramId,
    required this.email,
    required this.token,
    required this.source,
    required this.status,
    this.endUserId,
    this.invitedAt,
    this.joinedAt,
  });

  /// Reads a beta tester object.
  factory BetaTester.fromJson(Map<String, dynamic> json) => BetaTester(
        id: stringOrEmpty(json['id']),
        betaProgramId: stringOrEmpty(json['beta_program_id']),
        email: stringOrEmpty(json['email']),
        token: stringOrEmpty(json['token']),
        source: stringOrEmpty(json['source']),
        status: BetaTesterStatus(stringOrEmpty(json['status'])),
        endUserId: stringOrNull(json['end_user_id']),
        invitedAt: dateTimeOrNull(json['invited_at']),
        joinedAt: dateTimeOrNull(json['joined_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// The program this tester belongs to.
  final String betaProgramId;

  /// The tester's email address.
  final String email;

  /// Token identifying the tester in enrolment links.
  final String token;

  /// Where the tester came from.
  final String source;

  /// Whether they have accepted their invitation.
  final BetaTesterStatus status;

  /// The end user record they resolved to, once they joined.
  final String? endUserId;

  /// When they were invited.
  final DateTime? invitedAt;

  /// When they joined.
  final DateTime? joinedAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'beta_program_id': betaProgramId,
        'email': email,
        'token': token,
        'source': source,
        'status': status.value,
        'end_user_id': endUserId,
        'invited_at': invitedAt?.toIso8601String(),
        'joined_at': joinedAt?.toIso8601String(),
      };

  @override
  String toString() =>
      'BetaTester(id: $id, email: $email, status: ${status.value})';

  @override
  bool operator ==(Object other) =>
      other is BetaTester &&
      other.id == id &&
      other.betaProgramId == betaProgramId &&
      other.email == email &&
      other.token == token &&
      other.source == source &&
      other.status == status &&
      other.endUserId == endUserId &&
      other.invitedAt == invitedAt &&
      other.joinedAt == joinedAt;

  @override
  int get hashCode => Object.hash(
        id,
        betaProgramId,
        email,
        token,
        source,
        status,
        endUserId,
        invitedAt,
        joinedAt,
      );
}
