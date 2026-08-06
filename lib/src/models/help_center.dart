import 'common.dart';
import 'json.dart';

/// A help center article.
class Article {
  /// Creates an article.
  const Article({
    required this.id,
    required this.title,
    required this.slug,
    required this.body,
    required this.excerpt,
    required this.status,
    required this.helpfulCount,
    required this.notHelpfulCount,
    this.categoryId,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Reads an article object.
  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: stringOrEmpty(json['id']),
        title: stringOrEmpty(json['title']),
        slug: stringOrEmpty(json['slug']),
        body: stringOrEmpty(json['body']),
        excerpt: stringOrEmpty(json['excerpt']),
        status: ArticleStatus(stringOrEmpty(json['status'])),
        helpfulCount: intOrZero(json['helpful_count']),
        notHelpfulCount: intOrZero(json['not_helpful_count']),
        categoryId: stringOrNull(json['category_id']),
        publishedAt: dateTimeOrNull(json['published_at']),
        createdAt: dateTimeOrNull(json['created_at']),
        updatedAt: dateTimeOrNull(json['updated_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// Article headline.
  final String title;

  /// URL-safe name.
  final String slug;

  /// Markdown body — not HTML.
  final String body;

  /// Short summary shown in listings.
  final String excerpt;

  /// Whether the article is live.
  final ArticleStatus status;

  /// How many readers marked it helpful.
  final int helpfulCount;

  /// How many readers marked it unhelpful.
  final int notHelpfulCount;

  /// The category it belongs to, or `null` when uncategorized.
  final String? categoryId;

  /// When it went live, or `null` while unpublished.
  final DateTime? publishedAt;

  /// When it was created.
  final DateTime? createdAt;

  /// When it last changed.
  final DateTime? updatedAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'body': body,
        'excerpt': excerpt,
        'status': status.value,
        'category_id': categoryId,
        'published_at': publishedAt?.toIso8601String(),
        'helpful_count': helpfulCount,
        'not_helpful_count': notHelpfulCount,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  @override
  String toString() =>
      'Article(id: $id, slug: $slug, status: ${status.value}, title: $title)';

  @override
  bool operator ==(Object other) =>
      other is Article &&
      other.id == id &&
      other.title == title &&
      other.slug == slug &&
      other.body == body &&
      other.excerpt == excerpt &&
      other.status == status &&
      other.helpfulCount == helpfulCount &&
      other.notHelpfulCount == notHelpfulCount &&
      other.categoryId == categoryId &&
      other.publishedAt == publishedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        slug,
        body,
        excerpt,
        status,
        helpfulCount,
        notHelpfulCount,
        categoryId,
        publishedAt,
        createdAt,
        updatedAt,
      );
}

/// A ranked search hit.
///
/// Search returns a projection rather than whole articles — fetch the article
/// by id when you need its body.
class ArticleSearchResult {
  /// Creates a search result.
  const ArticleSearchResult({
    required this.id,
    required this.title,
    required this.slug,
    required this.snippet,
    required this.rank,
    this.categorySlug,
    this.categoryName,
  });

  /// Reads a search result object.
  factory ArticleSearchResult.fromJson(Map<String, dynamic> json) =>
      ArticleSearchResult(
        id: stringOrEmpty(json['id']),
        title: stringOrEmpty(json['title']),
        slug: stringOrEmpty(json['slug']),
        snippet: stringOrEmpty(json['snippet']),
        rank: json['rank'] is num ? (json['rank']! as num).toDouble() : 0,
        categorySlug: stringOrNull(json['category_slug']),
        categoryName: stringOrNull(json['category_name']),
      );

  /// Identifier of the matching article.
  final String id;

  /// Article headline.
  final String title;

  /// URL-safe name.
  final String slug;

  /// Matching excerpt with the query term in context.
  final String snippet;

  /// Relevance score; higher is better.
  final double rank;

  /// Slug of the article's category, when it has one.
  final String? categorySlug;

  /// Name of the article's category, when it has one.
  final String? categoryName;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'category_slug': categorySlug,
        'category_name': categoryName,
        'snippet': snippet,
        'rank': rank,
      };

  @override
  String toString() => 'ArticleSearchResult(id: $id, rank: $rank, $title)';

  @override
  bool operator ==(Object other) =>
      other is ArticleSearchResult &&
      other.id == id &&
      other.title == title &&
      other.slug == slug &&
      other.snippet == snippet &&
      other.rank == rank &&
      other.categorySlug == categorySlug &&
      other.categoryName == categoryName;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        slug,
        snippet,
        rank,
        categorySlug,
        categoryName,
      );
}

/// A help center category.
class ArticleCategory {
  /// Creates a category.
  const ArticleCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.sortOrder,
    this.createdAt,
  });

  /// Reads a category object.
  factory ArticleCategory.fromJson(Map<String, dynamic> json) =>
      ArticleCategory(
        id: stringOrEmpty(json['id']),
        name: stringOrEmpty(json['name']),
        slug: stringOrEmpty(json['slug']),
        description: stringOrEmpty(json['description']),
        sortOrder: intOrZero(json['sort_order']),
        createdAt: dateTimeOrNull(json['created_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// Display name.
  final String name;

  /// URL-safe name.
  final String slug;

  /// Short description.
  final String description;

  /// Position in the help center navigation; lower sorts first.
  final int sortOrder;

  /// When the category was created.
  final DateTime? createdAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'sort_order': sortOrder,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  String toString() => 'ArticleCategory(id: $id, slug: $slug, name: $name)';

  @override
  bool operator ==(Object other) =>
      other is ArticleCategory &&
      other.id == id &&
      other.name == name &&
      other.slug == slug &&
      other.description == description &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, name, slug, description, sortOrder, createdAt);
}
