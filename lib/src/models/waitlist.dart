import 'common.dart';
import 'json.dart';

/// A waitlist signup.
class WaitlistSignup {
  /// Creates a waitlist signup.
  const WaitlistSignup({
    required this.id,
    required this.email,
    required this.status,
    required this.referralCount,
    required this.referralCode,
    required this.token,
    required this.source,
    this.position,
    this.createdAt,
    this.invitedAt,
    this.joinedAt,
  });

  /// Reads a waitlist signup object.
  factory WaitlistSignup.fromJson(Map<String, dynamic> json) => WaitlistSignup(
        id: stringOrEmpty(json['id']),
        email: stringOrEmpty(json['email']),
        status: WaitlistStatus(stringOrEmpty(json['status'])),
        referralCount: intOrZero(json['referral_count']),
        referralCode: stringOrEmpty(json['referral_code']),
        token: stringOrEmpty(json['token']),
        source: stringOrEmpty(json['source']),
        position: intOrNull(json['position']),
        createdAt: dateTimeOrNull(json['created_at']),
        invitedAt: dateTimeOrNull(json['invited_at']),
        joinedAt: dateTimeOrNull(json['joined_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// The signup's email address.
  final String email;

  /// Where the signup sits in the queue.
  final WaitlistStatus status;

  /// How many people this signup has referred.
  final int referralCount;

  /// Code others can use to credit this signup with a referral.
  final String referralCode;

  /// Token identifying the signup in share links.
  final String token;

  /// Where the signup came from.
  final String source;

  /// Queue position, or `null` once the signup leaves the queue.
  final int? position;

  /// When they signed up.
  final DateTime? createdAt;

  /// When they were invited, if they have been.
  final DateTime? invitedAt;

  /// When they joined, if they have.
  final DateTime? joinedAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'status': status.value,
        'position': position,
        'referral_count': referralCount,
        'referral_code': referralCode,
        'token': token,
        'source': source,
        'created_at': createdAt?.toIso8601String(),
        'invited_at': invitedAt?.toIso8601String(),
        'joined_at': joinedAt?.toIso8601String(),
      };

  @override
  String toString() => 'WaitlistSignup(id: $id, email: $email, '
      'status: ${status.value}, position: $position)';

  @override
  bool operator ==(Object other) =>
      other is WaitlistSignup &&
      other.id == id &&
      other.email == email &&
      other.status == status &&
      other.referralCount == referralCount &&
      other.referralCode == referralCode &&
      other.token == token &&
      other.source == source &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.invitedAt == invitedAt &&
      other.joinedAt == joinedAt;

  @override
  int get hashCode => Object.hash(
        id,
        email,
        status,
        referralCount,
        referralCode,
        token,
        source,
        position,
        createdAt,
        invitedAt,
        joinedAt,
      );
}
