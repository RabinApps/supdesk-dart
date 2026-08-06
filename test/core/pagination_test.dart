import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

/// Builds a page whose fetcher serves from [pages], recording the params it was
/// asked for.
Page<String> pagedOver(
  List<({List<String> items, int limit, int offset, bool hasMore})> pages, {
  required List<Map<String, Object?>> requested,
}) {
  late final PageFetcher<String> fetch;
  var index = 1;

  fetch = (params) async {
    requested.add(params);
    final spec = pages[index++];

    return Page<String>(
      data: spec.items,
      pagination: PaginationMeta(
        limit: spec.limit,
        offset: spec.offset,
        hasMore: spec.hasMore,
      ),
      fetchPage: fetch,
      params: params,
    );
  };

  return Page<String>(
    data: pages.first.items,
    pagination: PaginationMeta(
      limit: pages.first.limit,
      offset: pages.first.offset,
      hasMore: pages.first.hasMore,
    ),
    fetchPage: fetch,
    params: const {'status': 'open'},
  );
}

void main() {
  group('PaginationMeta', () {
    test('reads the wire shape', () {
      final meta = PaginationMeta.fromJson({
        'limit': 20,
        'offset': 40,
        'has_more': true,
      });

      expect(meta.limit, 20);
      expect(meta.offset, 40);
      expect(meta.hasMore, isTrue);
      expect(meta.toJson(), {'limit': 20, 'offset': 40, 'has_more': true});
    });

    test('defaults missing fields rather than throwing', () {
      final meta = PaginationMeta.fromJson(const {});

      expect(meta.limit, 0);
      expect(meta.offset, 0);
      expect(meta.hasMore, isFalse);
    });

    test('compares by value', () {
      const a = PaginationMeta(limit: 1, offset: 2, hasMore: true);
      const b = PaginationMeta(limit: 1, offset: 2, hasMore: true);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
          a, isNot(const PaginationMeta(limit: 9, offset: 2, hasMore: true)));
      expect(a.toString(), contains('limit: 1'));
    });
  });

  group('Page', () {
    test('exposes an unmodifiable view of its items', () {
      final page = pagedOver(
        [
          (items: ['a'], limit: 20, offset: 0, hasMore: false)
        ],
        requested: [],
      );

      expect(page.data, ['a']);
      expect(() => page.data.add('b'), throwsUnsupportedError);
      expect(page.toString(), contains('1 items'));
    });

    test('treats an empty page as the end even when has_more is true', () {
      final page = pagedOver(
        [(items: <String>[], limit: 20, offset: 0, hasMore: true)],
        requested: [],
      );

      expect(page.hasNextPage(), isFalse);
      expect(page.nextPageParams(), isNull);
      expect(page.getNextPage, throwsStateError);
    });

    test('advances by the items returned, not by limit', () {
      final requested = <Map<String, Object?>>[];
      final page = pagedOver(
        [
          (items: ['a', 'b'], limit: 20, offset: 10, hasMore: true),
          (items: ['c'], limit: 20, offset: 12, hasMore: false),
        ],
        requested: requested,
      );

      expect(page.hasNextPage(), isTrue);
      expect(page.nextPageParams(), {
        'status': 'open',
        'offset': 12,
        'limit': 20,
      });
    });

    test('autoPaging walks every remaining page', () async {
      final requested = <Map<String, Object?>>[];
      final page = pagedOver(
        [
          (items: ['a', 'b'], limit: 2, offset: 0, hasMore: true),
          (items: ['c', 'd'], limit: 2, offset: 2, hasMore: true),
          (items: ['e'], limit: 2, offset: 4, hasMore: false),
        ],
        requested: requested,
      );

      expect(await page.autoPaging().toList(), ['a', 'b', 'c', 'd', 'e']);
      expect(requested, [
        {'status': 'open', 'offset': 2, 'limit': 2},
        {'status': 'open', 'offset': 4, 'limit': 2},
      ]);
    });

    test('toList collects everything', () async {
      final page = pagedOver(
        [
          (items: ['a'], limit: 1, offset: 0, hasMore: true),
          (items: ['b'], limit: 1, offset: 1, hasMore: false),
        ],
        requested: [],
      );

      expect(await page.toList(), ['a', 'b']);
    });

    test('getNextPage returns the following page', () async {
      final page = pagedOver(
        [
          (items: ['a'], limit: 1, offset: 0, hasMore: true),
          (items: ['b'], limit: 1, offset: 1, hasMore: false),
        ],
        requested: [],
      );

      final next = await page.getNextPage();

      expect(next.data, ['b']);
      expect(next.hasNextPage(), isFalse);
    });
  });
}
