// Every way of walking a list endpoint.
//
//   SUPDESK_API_KEY=sd_live_… dart run bin/pagination.dart
import 'dart:io';

import 'package:supdesk/supdesk.dart';

Future<void> main() async {
  final supdesk = SupDesk(apiKey: _env('SUPDESK_API_KEY'));

  try {
    // 1. One page. This is what a UI wants: a slice plus a cursor.
    final page = await supdesk.submissions.list(
      status: PostStatus.open,
      limit: 25,
    );

    print('page of ${page.data.length}, more: ${page.hasNextPage()}');
    print('limit ${page.pagination.limit}, offset ${page.pagination.offset}');

    // 2. Page by page, by hand. Note that the SDK advances the offset by the
    //    items actually returned, not by `limit`, so a short page never causes
    //    items to be skipped.
    var current = page;
    var pages = 1;
    while (current.hasNextPage() && pages < 5) {
      current = await current.getNextPage();
      pages++;
      print('page $pages: ${current.data.length} items');
    }

    // 3. The whole collection as a stream — one request per page, lazily. Use
    //    this for a scan or an export.
    var bugs = 0;
    await for (final submission in page.autoPaging()) {
      if (submission.type == SubmissionType.bug) bugs++;
    }
    print('$bugs bugs across every open submission');

    // 4. The whole collection in memory. Convenient, but it buys everything at
    //    once — prefer the stream above once the result set is large.
    final done = await supdesk.submissions
        .list(status: PostStatus.done, limit: 100)
        .then((page) => page.toList());
    print('${done.length} shipped');

    // 5. Search is the exception: ranked results, no pagination. `limit` caps
    //    at 100 server-side.
    for (final hit in await supdesk.articles.search('export', limit: 5)) {
      print('${hit.rank.toStringAsFixed(2)}  ${hit.title}  (${hit.slug})');
    }

    // 6. Streams compose, so filtering and taking a few is a one-liner that
    //    stops fetching as soon as it has enough.
    final firstThreeBugs = await page
        .autoPaging()
        .where((submission) => submission.type == SubmissionType.bug)
        .take(3)
        .toList();
    print('first three bugs: ${firstThreeBugs.map((s) => s.id).join(', ')}');
  } finally {
    supdesk.close();
  }
}

String _env(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    stderr.writeln('Set $name first.');
    exit(1);
  }
  return value;
}
