import 'common.dart';
import 'json.dart';

/// One message inside a support thread.
class Message {
  /// Creates a message.
  const Message({
    required this.id,
    required this.sender,
    required this.body,
    required this.via,
    this.memberId,
    this.createdAt,
  });

  /// Reads a message object.
  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: stringOrEmpty(json['id']),
        sender: MessageSender(stringOrEmpty(json['sender'])),
        body: stringOrEmpty(json['body']),
        via: stringOrEmpty(json['via']),
        memberId: stringOrNull(json['member_id']),
        createdAt: dateTimeOrNull(json['created_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// Who wrote it.
  final MessageSender sender;

  /// Message text.
  final String body;

  /// Channel the message arrived through.
  final String via;

  /// Set when a workspace member sent the message, `null` otherwise.
  final String? memberId;

  /// When it was sent.
  final DateTime? createdAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender.value,
        'member_id': memberId,
        'body': body,
        'via': via,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  String toString() => 'Message(id: $id, sender: ${sender.value})';

  @override
  bool operator ==(Object other) =>
      other is Message &&
      other.id == id &&
      other.sender == sender &&
      other.body == body &&
      other.via == via &&
      other.memberId == memberId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, sender, body, via, memberId, createdAt);
}

/// A support conversation.
class Thread {
  /// Creates a thread.
  const Thread({
    required this.id,
    required this.endUserId,
    required this.subject,
    required this.status,
    this.createdAt,
  });

  /// Reads a thread object from a list response.
  factory Thread.fromJson(Map<String, dynamic> json) => Thread(
        id: stringOrEmpty(json['id']),
        endUserId: stringOrEmpty(json['end_user_id']),
        subject: stringOrEmpty(json['subject']),
        status: ThreadStatus(stringOrEmpty(json['status'])),
        createdAt: dateTimeOrNull(json['created_at']),
      );

  /// Server-assigned identifier.
  final String id;

  /// The end user this conversation is with.
  final String endUserId;

  /// Conversation subject line.
  final String subject;

  /// Whether the thread is still open.
  final ThreadStatus status;

  /// When the thread was opened.
  final DateTime? createdAt;

  /// The wire representation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'end_user_id': endUserId,
        'subject': subject,
        'status': status.value,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  String toString() =>
      'Thread(id: $id, status: ${status.value}, subject: $subject)';

  @override
  bool operator ==(Object other) =>
      other is Thread &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.endUserId == endUserId &&
      other.subject == subject &&
      other.status == status &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, endUserId, subject, status, createdAt);
}

/// A thread fetched by id, which includes its messages.
class ThreadWithMessages extends Thread {
  /// Creates a thread with its messages.
  const ThreadWithMessages({
    required super.id,
    required super.endUserId,
    required super.subject,
    required super.status,
    required this.messages,
    super.createdAt,
  });

  /// Reads a thread object that carries a `messages` array.
  factory ThreadWithMessages.fromJson(Map<String, dynamic> json) =>
      ThreadWithMessages(
        id: stringOrEmpty(json['id']),
        endUserId: stringOrEmpty(json['end_user_id']),
        subject: stringOrEmpty(json['subject']),
        status: ThreadStatus(stringOrEmpty(json['status'])),
        createdAt: dateTimeOrNull(json['created_at']),
        messages: objectList(json['messages'])
            .map(Message.fromJson)
            .toList(growable: false),
      );

  /// Messages in the conversation, oldest first.
  final List<Message> messages;

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  @override
  String toString() => 'ThreadWithMessages(id: $id, status: ${status.value}, '
      '${messages.length} messages)';

  @override
  bool operator ==(Object other) =>
      other is ThreadWithMessages &&
      super == other &&
      listEquals(other.messages, messages);

  @override
  int get hashCode => Object.hash(super.hashCode, Object.hashAll(messages));
}
