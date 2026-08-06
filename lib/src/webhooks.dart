import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'core/errors.dart';
import 'models/json.dart';
import 'models/waitlist.dart';

/// The header SupDesk signs every webhook delivery with.
const String supDeskSignatureHeader = 'X-SupDesk-Signature';

/// Every event type SupDesk documents.
///
/// An extension type over [String], so a type added server-side arrives as
/// itself instead of failing to parse.
extension type const SupDeskWebhookEventType(String value) {
  /// A submission or feedback post was created.
  static const SupDeskWebhookEventType postCreated =
      SupDeskWebhookEventType('post.created');

  /// A post was edited.
  static const SupDeskWebhookEventType postUpdated =
      SupDeskWebhookEventType('post.updated');

  /// A post was deleted.
  static const SupDeskWebhookEventType postDeleted =
      SupDeskWebhookEventType('post.deleted');

  /// A post moved between workflow statuses.
  static const SupDeskWebhookEventType postStatusChanged =
      SupDeskWebhookEventType('post.status_changed');

  /// A comment was added to a post.
  static const SupDeskWebhookEventType commentCreated =
      SupDeskWebhookEventType('comment.created');

  /// A comment was edited.
  static const SupDeskWebhookEventType commentUpdated =
      SupDeskWebhookEventType('comment.updated');

  /// A comment was deleted.
  static const SupDeskWebhookEventType commentDeleted =
      SupDeskWebhookEventType('comment.deleted');

  /// A message was added to a support thread.
  static const SupDeskWebhookEventType messageCreated =
      SupDeskWebhookEventType('message.created');

  /// A message was edited.
  static const SupDeskWebhookEventType messageUpdated =
      SupDeskWebhookEventType('message.updated');

  /// A message was deleted.
  static const SupDeskWebhookEventType messageDeleted =
      SupDeskWebhookEventType('message.deleted');

  /// A beta tester submitted feedback.
  static const SupDeskWebhookEventType betaFeedbackCreated =
      SupDeskWebhookEventType('beta_feedback.created');

  /// Beta feedback was deleted.
  static const SupDeskWebhookEventType betaFeedbackDeleted =
      SupDeskWebhookEventType('beta_feedback.deleted');

  /// Someone joined the waitlist.
  static const SupDeskWebhookEventType waitlistSignupCreated =
      SupDeskWebhookEventType('waitlist_signup.created');

  /// A waitlist signup was invited.
  static const SupDeskWebhookEventType waitlistSignupInvited =
      SupDeskWebhookEventType('waitlist_signup.invited');

  /// A waitlist signup accepted their invitation.
  static const SupDeskWebhookEventType waitlistSignupJoined =
      SupDeskWebhookEventType('waitlist_signup.joined');

  /// A customer satisfaction survey was completed.
  static const SupDeskWebhookEventType csatSurveyCompleted =
      SupDeskWebhookEventType('csat_survey.completed');

  /// Every documented value.
  static const List<SupDeskWebhookEventType> values = [
    postCreated,
    postUpdated,
    postDeleted,
    postStatusChanged,
    commentCreated,
    commentUpdated,
    commentDeleted,
    messageCreated,
    messageUpdated,
    messageDeleted,
    betaFeedbackCreated,
    betaFeedbackDeleted,
    waitlistSignupCreated,
    waitlistSignupInvited,
    waitlistSignupJoined,
    csatSurveyCompleted,
  ];
}

/// A verified webhook delivery.
///
/// SupDesk publishes no per-event `data` schemas, so [data] stays an open map
/// rather than an invented model. The one exception is the `waitlist_signup.*`
/// family, which [asWaitlistSignup] decodes.
class SupDeskWebhookEvent {
  /// Creates an event.
  const SupDeskWebhookEvent({
    required this.type,
    required this.projectId,
    required this.data,
    this.timestamp,
  });

  /// Reads a webhook envelope.
  factory SupDeskWebhookEvent.fromJson(Map<String, dynamic> json) =>
      SupDeskWebhookEvent(
        type: SupDeskWebhookEventType(stringOrEmpty(json['event'])),
        projectId: stringOrEmpty(json['project_id']),
        data: objectOrNull(json['data']) ?? const {},
        timestamp: dateTimeOrNull(json['timestamp']),
      );

  /// What happened.
  final SupDeskWebhookEventType type;

  /// The project the event belongs to.
  final String projectId;

  /// Event payload, shaped by [type].
  final Map<String, dynamic> data;

  /// When SupDesk emitted the event.
  final DateTime? timestamp;

  /// Decodes [data] as a waitlist signup.
  ///
  /// Only meaningful for the `waitlist_signup.*` events; anything else yields a
  /// signup with empty fields.
  WaitlistSignup asWaitlistSignup() => WaitlistSignup.fromJson(data);

  @override
  String toString() =>
      'SupDeskWebhookEvent(${type.value}, project: $projectId)';
}

/// Computes the signature SupDesk would send for [payload].
///
/// Exported mainly for building test fixtures; verification should go through
/// [verifyWebhookSignature], which compares in constant time.
String computeWebhookSignature(Object payload, String secret) {
  final hmac = Hmac(sha256, utf8.encode(secret));
  return 'sha256=${hmac.convert(_toBytes(payload))}';
}

/// Verifies a webhook signature.
///
/// [payload] must be the raw request body — a [String] or a byte list. A
/// re-encoded map will never verify, because `jsonEncode` does not reproduce
/// the original whitespace or key order.
///
/// Returns `false` rather than throwing for any invalid signature, including a
/// malformed header.
bool verifyWebhookSignature({
  required Object payload,
  required String signature,
  required String secret,
}) {
  final provided = _parseSignatureHeader(signature);
  if (provided == null || secret.isEmpty) return false;

  final expected =
      computeWebhookSignature(payload, secret).substring('sha256='.length);

  return _constantTimeEquals(expected, provided);
}

/// Verifies a payload and parses it into an event.
///
/// Throws a [SupDeskSignatureVerificationException] if the signature does not
/// match, or if the verified payload is not a JSON object.
SupDeskWebhookEvent constructEvent({
  required Object payload,
  required String signature,
  required String secret,
}) =>
    _constructEvent(payload, signature, secret);

SupDeskWebhookEvent _constructEvent(
  Object payload,
  String signature,
  String secret,
) {
  final verified = verifyWebhookSignature(
    payload: payload,
    signature: signature,
    secret: secret,
  );

  if (!verified) {
    throw const SupDeskSignatureVerificationException(
      'Webhook signature does not match the payload. Make sure you are passing '
      'the raw request body — a re-encoded JSON object will never verify.',
    );
  }

  final text = payload is String
      ? payload
      : utf8.decode(_toBytes(payload), allowMalformed: true);

  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const SupDeskSignatureVerificationException(
      'Webhook payload passed signature verification but is not valid JSON.',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw const SupDeskSignatureVerificationException(
      'Webhook payload passed signature verification but is not a JSON object.',
    );
  }

  return SupDeskWebhookEvent.fromJson(decoded);
}

/// Verifies and parses a webhook from a raw body and its request headers.
///
/// Header lookup is case-insensitive, so this works with `dart:io`'s
/// `HttpRequest`, shelf, dart_frog or any other server that hands you a map.
///
/// ```dart
/// final event = constructEventFromHeaders(
///   payload: await utf8.decodeStream(request),
///   headers: {for (final h in request.headers.keys) h: request.headers.value(h)!},
///   secret: webhookSecret,
/// );
/// ```
SupDeskWebhookEvent constructEventFromHeaders({
  required Object payload,
  required Map<String, String> headers,
  required String secret,
}) =>
    _constructEvent(payload, _findSignatureHeader(headers) ?? '', secret);

/// A signing secret bound to the webhook helpers, for callers who prefer an
/// object to a bag of functions.
class Webhooks {
  /// Binds the helpers to one signing secret.
  Webhooks(this.secret) {
    if (secret.isEmpty) {
      throw const SupDeskConfigurationException(
        'A webhook signing secret is required.',
      );
    }
  }

  /// The signing secret shared with SupDesk.
  final String secret;

  /// Whether [signature] matches [payload].
  bool verify(Object payload, String signature) => verifyWebhookSignature(
        payload: payload,
        signature: signature,
        secret: secret,
      );

  /// Verifies and parses a delivery.
  SupDeskWebhookEvent constructEvent(Object payload, String signature) =>
      _constructEvent(payload, signature, secret);

  /// Verifies and parses a delivery, finding the signature in [headers].
  SupDeskWebhookEvent constructEventFromHeaders(
    Object payload,
    Map<String, String> headers,
  ) =>
      _constructEvent(payload, _findSignatureHeader(headers) ?? '', secret);

  /// Signs [payload], for building fixtures.
  String sign(Object payload) => computeWebhookSignature(payload, secret);
}

final RegExp _signaturePattern = RegExp(r'^sha256=([0-9a-f]+)$');

String? _parseSignatureHeader(String signature) {
  final match = _signaturePattern.firstMatch(signature.trim().toLowerCase());
  return match?.group(1);
}

String? _findSignatureHeader(Map<String, String> headers) {
  final wanted = supDeskSignatureHeader.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == wanted) return entry.value;
  }
  return null;
}

List<int> _toBytes(Object payload) {
  if (payload is String) return utf8.encode(payload);
  if (payload is Uint8List) return payload;
  if (payload is List<int>) return payload;

  throw ArgumentError.value(
    payload,
    'payload',
    'Webhook payloads must be a String or a List<int> of the raw request body.',
  );
}

/// Compares two hex digests without an early return.
///
/// A plain `==` short-circuits on the first differing character, which leaks
/// how much of a forged signature was correct and makes the digest guessable
/// byte by byte. Comparing digests rather than secrets makes the length check
/// harmless: SHA-256 hex is always 64 characters.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;

  var mismatch = 0;
  for (var i = 0; i < a.length; i++) {
    mismatch |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }

  return mismatch == 0;
}
