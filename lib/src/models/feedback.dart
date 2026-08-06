import 'common.dart';
import 'json.dart';

/// General product feedback, separate from bug and feature submissions.
class Feedback {
  /// Creates a feedback item.
  const Feedback({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    this.createdAt,
  });

  /// Reads the `data` object of a feedback response.
  factory Feedback.fromJson(Map<String, dynamic> json) => Feedback(
        id: stringOrEmpty(json['id']),
        type: stringOrEmpty(json['type']),
        title: stringOrEmpty(json['title']),
        body: stringOrEmpty(json['body']),
        status: PostStatus(stringOrEmpty(json['status'])),
        createdAt: dateTimeOrNull(json['created_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// Always `feedback` today; kept as a string so a new kind does not break
  /// parsing.
  final String type;

  /// One-line summary.
  final String title;

  /// Full description.
  final String body;

  /// Where the item sits in the workflow.
  final PostStatus status;

  /// When it was filed. `null` if the API omitted or malformed the field.
  final DateTime? createdAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'status': status.value,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  String toString() =>
      'Feedback(id: $id, status: ${status.value}, title: $title)';

  @override
  bool operator ==(Object other) =>
      other is Feedback &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.body == body &&
      other.status == status &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, type, title, body, status, createdAt);
}
