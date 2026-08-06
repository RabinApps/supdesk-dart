import 'package:supdesk/src/core/query.dart';
import 'package:test/test.dart';

void main() {
  group('buildQueryString', () {
    test('returns an empty string for no parameters', () {
      expect(buildQueryString(null), '');
      expect(buildQueryString({}), '');
    });

    test('drops null but keeps false and zero', () {
      expect(
        buildQueryString({'a': null, 'b': false, 'c': 0}),
        '?b=false&c=0',
      );
    });

    test('returns an empty string when every value is null', () {
      expect(buildQueryString({'a': null, 'b': null}), '');
    });

    test('repeats iterable values', () {
      expect(
        buildQueryString({
          'labels': ['new', 'fixed'],
        }),
        '?labels=new&labels=fixed',
      );
    });

    test('percent-encodes keys and values', () {
      expect(
        buildQueryString({'q': 'how to export?', 'a&b': 'c=d'}),
        '?q=how+to+export%3F&a%26b=c%3Dd',
      );
    });
  });

  group('joinUrl', () {
    test('inserts exactly one slash', () {
      const expected = 'https://api.supdesk.app/v1/submissions';

      expect(joinUrl('https://api.supdesk.app/v1', '/submissions'), expected);
      expect(joinUrl('https://api.supdesk.app/v1/', 'submissions'), expected);
      expect(
          joinUrl('https://api.supdesk.app/v1//', '//submissions'), expected);
      expect(joinUrl('https://api.supdesk.app/v1', 'submissions'), expected);
    });
  });

  group('encodePathSegment', () {
    test('stops an id from escaping its segment', () {
      expect(encodePathSegment('../admin'), '..%2Fadmin');
      expect(encodePathSegment('a?b=c'), 'a%3Fb%3Dc');
    });

    test('accepts non-string ids', () {
      expect(encodePathSegment(42), '42');
    });
  });
}
