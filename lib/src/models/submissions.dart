import 'common.dart';
import 'json.dart';

/// A bug report or feature request.
class Submission {
  /// Creates a submission.
  const Submission({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    this.createdAt,
  });

  /// Reads the `data` object of a submissions response.
  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
        id: stringOrEmpty(json['id']),
        type: SubmissionType(stringOrEmpty(json['type'])),
        title: stringOrEmpty(json['title']),
        body: stringOrEmpty(json['body']),
        status: PostStatus(stringOrEmpty(json['status'])),
        createdAt: dateTimeOrNull(json['created_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// Whether this is a bug or a feature request.
  final SubmissionType type;

  /// One-line summary.
  final String title;

  /// Full description.
  final String body;

  /// Where the submission sits in the workflow.
  final PostStatus status;

  /// When it was filed. `null` if the API omitted or malformed the field.
  final DateTime? createdAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'title': title,
        'body': body,
        'status': status.value,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  String toString() => 'Submission(id: $id, type: ${type.value}, '
      'status: ${status.value}, title: $title)';

  @override
  bool operator ==(Object other) =>
      other is Submission &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.body == body &&
      other.status == status &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, type, title, body, status, createdAt);
}
