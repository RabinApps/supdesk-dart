// Waitlist and beta programs: invite a batch, then enrol the ones who joined.
//
//   SUPDESK_API_KEY=sd_live_… dart run bin/waitlist_and_beta.dart
import 'dart:io';

import 'package:supdesk/supdesk.dart';

Future<void> main() async {
  final supdesk = SupDesk(apiKey: _env('SUPDESK_API_KEY'));

  try {
    // The waitlist list endpoint defaults to 25 per page, not 20, and `search`
    // filters on an email substring.
    final waiting = await supdesk.waitlist.list(
      status: WaitlistStatus.waiting,
      limit: 25,
    );

    print('${waiting.data.length} waiting on this page');
    for (final signup in waiting.data) {
      print(
        '  #${signup.position ?? '—'}  ${signup.email}  '
        '${signup.referralCount} referrals',
      );
    }

    // Invite the ten furthest up the queue. Moving a signup between waiting,
    // invited and joined is what `update` is for.
    final queue = waiting.data.toList()
      ..sort(
        (a, b) => (a.position ?? 1 << 30).compareTo(b.position ?? 1 << 30),
      );

    for (final signup in queue.take(10)) {
      final invited = await supdesk.waitlist.update(
        signup.id,
        status: WaitlistStatus.invited,
      );
      print('invited ${invited.email} at ${invited.invitedAt}');
    }

    // A beta program is the thing testers are invited into. `status` is a plain
    // string here because SupDesk documents no fixed set of values.
    final program = await supdesk.beta.programs.create(
      name: 'Autumn beta',
      version: '2.0.0-beta.1',
      summary: 'The rewritten editor.',
      accessUrl: 'https://example.test/beta',
      accessInstructions: 'Install from TestFlight, then sign in as usual.',
      status: 'active',
      allowPublicSignup: false,
      feedbackDeadline: DateTime.now().toUtc().add(const Duration(days: 30)),
    );
    print('program ${program.id} (${program.slug})');

    // Testers are nested under a program, so every call takes the program id
    // first. There is no update endpoint for a tester — add or remove.
    for (final signup in queue.take(10)) {
      final tester = await supdesk.beta.testers.create(
        program.id,
        email: signup.email,
      );
      print('enrolled ${tester.email} — ${tester.status.value}');
    }

    // Who actually turned up.
    final testers = await supdesk.beta.testers.list(program.id);
    final joined = await testers
        .autoPaging()
        .where((tester) => tester.status == BetaTesterStatus.joined)
        .length;
    print('$joined of ${testers.pagination.limit} have joined so far');

    // Closing the program off to new signups is an update.
    await supdesk.beta.programs.update(program.id, status: 'closed');
  } on LimitReachedException {
    print('Monthly quota exhausted.');
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
