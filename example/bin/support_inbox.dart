// Support threads: open one, reply to it, close it.
//
//   SUPDESK_API_KEY=sd_live_… dart run bin/support_inbox.dart
import 'dart:io';

import 'package:supdesk/supdesk.dart';

Future<void> main() async {
  final supdesk = SupDesk(apiKey: _env('SUPDESK_API_KEY'));

  try {
    // `list` returns threads — the conversations, without their messages.
    final open = await supdesk.messages.list(status: ThreadStatus.open);
    print('${open.data.length} open threads');

    for (final thread in open.data.take(5)) {
      print('  ${thread.id}  ${thread.subject}');
    }

    // `get` is what includes the messages.
    if (open.data.isNotEmpty) {
      final thread = await supdesk.messages.get(open.data.first.id);
      for (final message in thread.messages) {
        final who = switch (message.sender.value) {
          'end_user' => 'customer',
          'member' => 'us (${message.memberId})',
          _ => message.sender.value,
        };
        print('$who via ${message.via}: ${message.body}');
      }
    }

    // Opening a thread creates the end user if they are new. `locale` picks the
    // language of the notification email they get.
    final created = await supdesk.messages.create(
      email: 'ada@example.com',
      name: 'Ada Lovelace',
      subject: 'Invoice question',
      body: 'Following up on the charge from last week.',
      locale: SupDeskLocale.en,
    );
    print('opened ${created.id} with ${created.messages.length} message(s)');

    // Replies default to `member` — you. Sending as `end_user` is for
    // backfilling a conversation that started somewhere else.
    final reply = await supdesk.messages.addMessage(
      created.id,
      body: 'Thanks for writing in — checking with billing now.',
      sender: MessageSender.member,
    );
    print('replied ${reply.id} at ${reply.createdAt}');

    // Closing is an update. Editing the subject works the same way.
    final closed = await supdesk.messages.update(
      created.id,
      status: ThreadStatus.closed,
      subject: 'Invoice question (resolved)',
    );
    print('closed: ${closed.status.value}');
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
