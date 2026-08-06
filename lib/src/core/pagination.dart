/// The `pagination` object every SupDesk list endpoint returns.
class PaginationMeta {
  /// Creates pagination metadata.
  const PaginationMeta({
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  /// Reads a `{ limit, offset, has_more }` object.
  factory PaginationMeta.fromJson(Map<String, dynamic> json) => PaginationMeta(
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
        hasMore: json['has_more'] == true,
      );

  /// Page size the server applied.
  final int limit;

  /// Offset of the first item on this page.
  final int offset;

  /// Whether the server reports more results after this page.
  final bool hasMore;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'limit': limit,
        'offset': offset,
        'has_more': hasMore,
      };

  @override
  String toString() =>
      'PaginationMeta(limit: $limit, offset: $offset, hasMore: $hasMore)';

  @override
  bool operator ==(Object other) =>
      other is PaginationMeta &&
      other.limit == limit &&
      other.offset == offset &&
      other.hasMore == hasMore;

  @override
  int get hashCode => Object.hash(limit, offset, hasMore);
}

/// Shared `limit`/`offset` parameters, mixed into every list-params class.
mixin PaginationParams {
  /// Page size.
  int? get limit;

  /// Index of the first item to return.
  int? get offset;
}

/// Fetches one page for the given query parameters.
typedef PageFetcher<T> = Future<Page<T>> Function(Map<String, Object?> params);

/// One page of results, which also knows how to fetch the next one.
///
/// [autoPaging] walks *every* remaining page, so callers rarely need to touch
/// offsets by hand:
///
/// ```dart
/// final page = await supdesk.submissions.list(status: PostStatus.open);
/// await for (final submission in page.autoPaging()) {
///   print(submission.title);
/// }
/// ```
class Page<T> {
  /// Creates a page bound to the fetcher that produced it.
  Page({
    required List<T> data,
    required this.pagination,
    required PageFetcher<T> fetchPage,
    required Map<String, Object?> params,
  })  : data = List<T>.unmodifiable(data),
        _fetchPage = fetchPage,
        _params = params;

  /// The items on this page.
  final List<T> data;

  /// Server-reported paging state for this page.
  final PaginationMeta pagination;

  final PageFetcher<T> _fetchPage;
  final Map<String, Object?> _params;

  /// Whether another page exists.
  ///
  /// An empty page is treated as the end even when the server says `has_more`.
  /// Trusting the flag alone would spin forever against a buggy or racing
  /// response, which is a much worse failure than stopping one page early.
  bool hasNextPage() => pagination.hasMore && data.isNotEmpty;

  /// Query parameters that would fetch the next page, or `null` if there is
  /// none.
  Map<String, Object?>? nextPageParams() {
    if (!hasNextPage()) return null;

    return {
      ..._params,
      // Advance by what was actually returned rather than by `limit`, so a
      // short page never causes items to be skipped.
      'offset': pagination.offset + data.length,
      'limit': pagination.limit,
    };
  }

  /// Fetches the next page.
  ///
  /// Throws a [StateError] if there is not one — check [hasNextPage] first.
  Future<Page<T>> getNextPage() {
    final params = nextPageParams();
    if (params == null) {
      throw StateError('No next page: this is the last page of results.');
    }

    return _fetchPage(params);
  }

  /// Streams every item across every remaining page, one request per page.
  Stream<T> autoPaging() async* {
    var page = this;

    for (;;) {
      for (final item in page.data) {
        yield item;
      }
      if (!page.hasNextPage()) return;
      page = await page.getNextPage();
    }
  }

  /// Collects every remaining item into a list.
  ///
  /// Convenience for small result sets — this buys the whole collection into
  /// memory, so prefer [autoPaging] for large ones.
  Future<List<T>> toList() => autoPaging().toList();

  @override
  String toString() => 'Page<$T>(${data.length} items, $pagination)';
}
