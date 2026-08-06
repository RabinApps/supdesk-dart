import 'common.dart';
import 'json.dart';

/// A public changelog entry.
class ChangelogEntry {
  /// Creates a changelog entry.
  const ChangelogEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.labels,
    required this.locale,
    required this.version,
    this.publishedAt,
  });

  /// Reads the `data` object of a changelog response.
  factory ChangelogEntry.fromJson(Map<String, dynamic> json) => ChangelogEntry(
        id: stringOrEmpty(json['id']),
        title: stringOrEmpty(json['title']),
        body: stringOrEmpty(json['body']),
        labels: stringList(json['labels']),
        locale: SupDeskLocale(stringOrEmpty(json['locale'])),
        version: stringOrEmpty(json['version']),
        publishedAt: dateTimeOrNull(json['published_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// Entry headline.
  final String title;

  /// Markdown body.
  final String body;

  /// Free-form labels such as `New`, `Improved`, `Fixed`.
  final List<String> labels;

  /// Language this entry is written in.
  final SupDeskLocale locale;

  /// Semver string.
  final String version;

  /// When it went live, or `null` while it is a draft.
  final DateTime? publishedAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'labels': labels,
        'locale': locale.value,
        'version': version,
        'published_at': publishedAt?.toIso8601String(),
      };

  @override
  String toString() =>
      'ChangelogEntry(id: $id, version: $version, title: $title)';

  @override
  bool operator ==(Object other) =>
      other is ChangelogEntry &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      listEquals(other.labels, labels) &&
      other.locale == locale &&
      other.version == version &&
      other.publishedAt == publishedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        body,
        Object.hashAll(labels),
        locale,
        version,
        publishedAt,
      );
}
