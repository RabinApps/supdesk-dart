import '../core/pagination.dart';
import '../core/query.dart';
import '../models/help_center.dart';
import '../models/json.dart';
import 'base.dart';

/// Help center categories.
class ArticleCategories extends APIResource {
  /// Binds the resource to a transport.
  ArticleCategories(super.client);

  /// `GET /article-categories` — the returned [Page] streams every page.
  Future<Page<ArticleCategory>> list({
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<ArticleCategory>(
        '/article-categories',
        {'limit': limit, 'offset': offset},
        ArticleCategory.fromJson,
        options: options,
      );

  /// `GET /article-categories/:id`
  Future<ArticleCategory> get(String id, {CallOptions? options}) =>
      requestObject(
        'GET',
        '/article-categories/${encodePathSegment(id)}',
        ArticleCategory.fromJson,
        options: options,
      );

  /// `POST /article-categories`
  Future<ArticleCategory> create({
    required String name,
    String? description,
    int? sortOrder,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/article-categories',
        ArticleCategory.fromJson,
        body: pruneNulls({
          'name': name,
          'description': description,
          'sort_order': sortOrder,
        }),
        options: options,
      );

  /// `PATCH /article-categories/:id`
  Future<ArticleCategory> update(
    String id, {
    String? name,
    String? description,
    int? sortOrder,
    CallOptions? options,
  }) =>
      requestObject(
        'PATCH',
        '/article-categories/${encodePathSegment(id)}',
        ArticleCategory.fromJson,
        body: pruneNulls({
          'name': name,
          'description': description,
          'sort_order': sortOrder,
        }),
        options: options,
      );

  /// `DELETE /article-categories/:id`
  ///
  /// Articles in the category are kept; they become uncategorized.
  Future<void> delete(String id, {CallOptions? options}) => requestEmpty(
        'DELETE',
        '/article-categories/${encodePathSegment(id)}',
        options: options,
      );
}
