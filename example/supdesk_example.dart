// A tour of the SupDesk Dart client.
//
// Run it against your own project:
//
//   SUPDESK_API_KEY=sd_live_… dart run example/supdesk_example.dart
//
// Everything here is server-side. Never ship the API key to an end user.
import 'dart:io';

import 'package:supdesk/supdesk.dart';

Future<void> main() async {
  final apiKey = Platform.environment['SUPDESK_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set SUPDESK_API_KEY first.');
    exitCode = 1;
    return;
  }

  final supdesk = SupDesk(apiKey: apiKey);

  try {
    // Reads work on every plan.
    final page = await supdesk.submissions.list(
      status: PostStatus.open,
      limit: 25,
    );

    print('${page.data.length} open submissions on the first page');

    // Iterating walks every remaining page for you, one request at a time.
    await for (final submission in page.autoPaging()) {
      print('  [${submission.type.value}] ${submission.title}');
    }

    // Search is the one list endpoint that is ranked rather than paginated.
    for (final hit in await supdesk.articles.search('export', limit: 5)) {
      print('${hit.rank.toStringAsFixed(2)}  ${hit.title}');
    }

    // Writes work on every plan; creates count against the monthly quota.
    final created = await supdesk.submissions.create(
      type: SubmissionType.bug,
      title: 'Export button does nothing',
      email: 'user@example.com',
      body: 'Clicking Export on the reports page has no effect.',
      locale: SupDeskLocale.en,
    );

    print('filed ${created.id}');
  } on LimitReachedException {
    print('Monthly submission quota exhausted.');
  } on SupDeskApiException catch (error) {
    print(
      'SupDesk returned ${error.statusCode} ${error.code}: ${error.message}',
    );
  } on SupDeskException catch (error) {
    // Every failure this SDK raises shares one base class.
    print('Request failed: ${error.message}');
  } finally {
    supdesk.close();
  }
}
