import 'dart:convert';
import 'dart:typed_data';

import 'package:supdesk/supdesk.dart';
import 'package:test/test.dart';

const secret = 'whsec_test';

const payload = '{"event":"waitlist_signup.joined",'
    '"timestamp":"2026-01-02T03:04:05.000Z",'
    '"project_id":"proj_1",'
    '"data":{"id":"wl_1","email":"ada@example.com","status":"joined",'
    '"position":null,"referral_count":2,"referral_code":"ABC","token":"tok",'
    '"source":"landing"}}';

void main() {
  group('computeWebhookSignature', () {
    test('produces the documented sha256= form', () {
      final signature = computeWebhookSignature(payload, secret);

      expect(signature, startsWith('sha256='));
      expect(signature.substring(7), hasLength(64));
      expect(RegExp(r'^sha256=[0-9a-f]{64}$').hasMatch(signature), isTrue);
    });

    test('is stable across string and byte payloads', () {
      expect(
        computeWebhookSignature(utf8.encode(payload), secret),
        computeWebhookSignature(payload, secret),
      );
      expect(
        computeWebhookSignature(
            Uint8List.fromList(utf8.encode(payload)), secret),
        computeWebhookSignature(payload, secret),
      );
    });

    test('changes with the secret', () {
      expect(
        computeWebhookSignature(payload, 'other'),
        isNot(computeWebhookSignature(payload, secret)),
      );
    });

    test('rejects a payload that is neither text nor bytes', () {
      expect(
        () => computeWebhookSignature(42, secret),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('verifyWebhookSignature', () {
    test('accepts a signature it just produced', () {
      expect(
        verifyWebhookSignature(
          payload: payload,
          signature: computeWebhookSignature(payload, secret),
          secret: secret,
        ),
        isTrue,
      );
    });

    test('accepts an uppercase hex digest', () {
      final signature = computeWebhookSignature(payload, secret).toUpperCase();

      expect(
        verifyWebhookSignature(
          payload: payload,
          signature: signature,
          secret: secret,
        ),
        isTrue,
      );
    });

    test('rejects a tampered body', () {
      final signature = computeWebhookSignature(payload, secret);

      expect(
        verifyWebhookSignature(
          payload: payload.replaceAll('ada@', 'mallory@'),
          signature: signature,
          secret: secret,
        ),
        isFalse,
      );
    });

    test('rejects the wrong secret', () {
      expect(
        verifyWebhookSignature(
          payload: payload,
          signature: computeWebhookSignature(payload, 'other'),
          secret: secret,
        ),
        isFalse,
      );
    });

    test('rejects a malformed or missing header', () {
      for (final signature in [
        '',
        'nope',
        'sha1=abc',
        'sha256=',
        'sha256=zz'
      ]) {
        expect(
          verifyWebhookSignature(
            payload: payload,
            signature: signature,
            secret: secret,
          ),
          isFalse,
          reason: signature,
        );
      }
    });

    test('rejects an empty secret', () {
      expect(
        verifyWebhookSignature(
          payload: payload,
          signature: computeWebhookSignature(payload, ''),
          secret: '',
        ),
        isFalse,
      );
    });

    test('rejects a digest of the wrong length', () {
      expect(
        verifyWebhookSignature(
          payload: payload,
          signature: 'sha256=abcdef',
          secret: secret,
        ),
        isFalse,
      );
    });
  });

  group('constructEvent', () {
    test('returns a parsed event for a valid delivery', () {
      final event = constructEvent(
        payload: payload,
        signature: computeWebhookSignature(payload, secret),
        secret: secret,
      );

      expect(event.type, SupDeskWebhookEventType.waitlistSignupJoined);
      expect(event.projectId, 'proj_1');
      expect(event.timestamp, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(event.data['email'], 'ada@example.com');
      expect(event.toString(), contains('waitlist_signup.joined'));
    });

    test('decodes the waitlist payload it documents', () {
      final event = constructEvent(
        payload: payload,
        signature: computeWebhookSignature(payload, secret),
        secret: secret,
      );

      final signup = event.asWaitlistSignup();
      expect(signup.email, 'ada@example.com');
      expect(signup.status, WaitlistStatus.joined);
      expect(signup.referralCount, 2);
    });

    test('accepts a byte payload', () {
      final bytes = utf8.encode(payload);

      final event = constructEvent(
        payload: bytes,
        signature: computeWebhookSignature(bytes, secret),
        secret: secret,
      );

      expect(event.projectId, 'proj_1');
    });

    test('throws when the signature does not match', () {
      expect(
        () => constructEvent(
          payload: payload,
          signature: 'sha256=${'0' * 64}',
          secret: secret,
        ),
        throwsA(
          isA<SupDeskSignatureVerificationException>().having(
            (error) => error.message,
            'message',
            contains('raw request body'),
          ),
        ),
      );
    });

    test('throws when a verified payload is not JSON', () {
      const body = 'not json';

      expect(
        () => constructEvent(
          payload: body,
          signature: computeWebhookSignature(body, secret),
          secret: secret,
        ),
        throwsA(
          isA<SupDeskSignatureVerificationException>().having(
            (error) => error.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('throws when a verified payload is not an object', () {
      const body = '[1,2,3]';

      expect(
        () => constructEvent(
          payload: body,
          signature: computeWebhookSignature(body, secret),
          secret: secret,
        ),
        throwsA(
          isA<SupDeskSignatureVerificationException>().having(
            (error) => error.message,
            'message',
            contains('not a JSON object'),
          ),
        ),
      );
    });

    test('keeps an unrecognized event type intact', () {
      const body = '{"event":"post.archived","project_id":"proj_1"}';

      final event = constructEvent(
        payload: body,
        signature: computeWebhookSignature(body, secret),
        secret: secret,
      );

      expect(event.type.value, 'post.archived');
      expect(event.data, isEmpty);
      expect(event.timestamp, isNull);
    });
  });

  group('constructEventFromHeaders', () {
    test('finds the signature whatever the header casing', () {
      final signature = computeWebhookSignature(payload, secret);

      for (final name in [
        supDeskSignatureHeader,
        'x-supdesk-signature',
        'X-SUPDESK-SIGNATURE',
      ]) {
        final event = constructEventFromHeaders(
          payload: payload,
          headers: {'content-type': 'application/json', name: signature},
          secret: secret,
        );

        expect(event.projectId, 'proj_1', reason: name);
      }
    });

    test('throws when the header is absent', () {
      expect(
        () => constructEventFromHeaders(
          payload: payload,
          headers: const {},
          secret: secret,
        ),
        throwsA(isA<SupDeskSignatureVerificationException>()),
      );
    });
  });

  group('Webhooks', () {
    test('binds one secret to every helper', () {
      final webhooks = Webhooks(secret);
      final signature = webhooks.sign(payload);

      expect(webhooks.secret, secret);
      expect(webhooks.verify(payload, signature), isTrue);
      expect(webhooks.verify(payload, 'sha256=${'0' * 64}'), isFalse);
      expect(webhooks.constructEvent(payload, signature).projectId, 'proj_1');
      expect(
        webhooks.constructEventFromHeaders(
          payload,
          {supDeskSignatureHeader: signature},
        ).projectId,
        'proj_1',
      );
    });

    test('refuses an empty secret', () {
      expect(
        () => Webhooks(''),
        throwsA(isA<SupDeskConfigurationException>()),
      );
    });
  });

  test('every documented event type is exposed', () {
    expect(SupDeskWebhookEventType.values, hasLength(16));
    expect(
      SupDeskWebhookEventType.values.map((type) => type.value),
      containsAll([
        'post.created',
        'post.updated',
        'post.deleted',
        'post.status_changed',
        'comment.created',
        'comment.updated',
        'comment.deleted',
        'message.created',
        'message.updated',
        'message.deleted',
        'beta_feedback.created',
        'beta_feedback.deleted',
        'waitlist_signup.created',
        'waitlist_signup.invited',
        'waitlist_signup.joined',
        'csat_survey.completed',
      ]),
    );
  });
}
