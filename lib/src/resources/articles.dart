import '../core/pagination.dart';
import '../core/query.dart';
import '../models/common.dart';
import '../models/help_center.dart';
import '../models/json.dart';
import 'base.dart';

/// Help center articles.
class Articles extends APIResource {
  /// Binds the resource to a transport.
  Articles(super.client);

  /// `GET /articles` — the returned [Page] streams every page.
  Future<Page<Article>> list({
    ArticleStatus? status,
    String? categoryId,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<Article>(
        '/articles',
        {
          'status': status?.value,
          'category_id': categoryId,
          'limit': limit,
          'offset': offset,
        },
        Article.fromJson,
        options: options,
      );

  /// `GET /articles/search`
  ///
  /// Returns ranked projections rather than full articles, and is not
  /// paginated — pass [limit] (max 100) to widen the result set.
  Future<List<ArticleSearchResult>> search(
    String query, {
    int? limit,
    CallOptions? options,
  }) =>
      requestList(
        'GET',
        '/articles/search',
        ArticleSearchResult.fromJson,
        query: {'q': query, 'limit': limit},
        options: options,
      );

  /// `GET /articles/:id`
  Future<Article> get(String id, {CallOptions? options}) => requestObject(
        'GET',
        '/articles/${encodePathSegment(id)}',
        Article.fromJson,
        options: options,
      );

  /// `POST /articles` — creates a draft.
  Future<Article> create({
    required String title,
    String? body,
    String? excerpt,
    String? slug,
    String? categoryId,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/articles',
        Article.fromJson,
        body: pruneNulls({
          'title': title,
          'body': body,
          'excerpt': excerpt,
          'slug': slug,
          'category_id': categoryId,
        }),
        options: options,
      );

  /// `PATCH /articles/:id` — also how an article is published.
  Future<Article> update(
    String id, {
    String? title,
    String? body,
    String? excerpt,
    String? slug,
    String? categoryId,
    ArticleStatus? status,
    CallOptions? options,
  }) =>
      requestObject(
        'PATCH',
        '/articles/${encodePathSegment(id)}',
        Article.fromJson,
        body: pruneNulls({
          'title': title,
          'body': body,
          'excerpt': excerpt,
          'slug': slug,
          'category_id': categoryId,
          'status': status?.value,
        }),
        options: options,
      );

  /// `DELETE /articles/:id`
  Future<void> delete(String id, {CallOptions? options}) => requestEmpty(
        'DELETE',
        '/articles/${encodePathSegment(id)}',
        options: options,
      );
}
