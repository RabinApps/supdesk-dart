import '../core/pagination.dart';
import '../core/query.dart';
import '../models/common.dart';
import '../models/json.dart';
import '../models/messages.dart';
import 'base.dart';

/// Support conversations.
///
/// A thread is the conversation; [addMessage] appends a reply to one.
class Messages extends APIResource {
  /// Binds the resource to a transport.
  Messages(super.client);

  /// `GET /messages` — the returned [Page] streams every page of threads.
  Future<Page<Thread>> list({
    ThreadStatus? status,
    int? limit,
    int? offset,
    CallOptions? options,
  }) =>
      listPage<Thread>(
        '/messages',
        {'status': status?.value, 'limit': limit, 'offset': offset},
        Thread.fromJson,
        options: options,
      );

  /// `GET /messages/:threadId` — includes the thread's messages.
  Future<ThreadWithMessages> get(String threadId, {CallOptions? options}) =>
      requestObject(
        'GET',
        '/messages/${encodePathSegment(threadId)}',
        ThreadWithMessages.fromJson,
        options: options,
      );

  /// `POST /messages` — opens a thread with its initial message.
  Future<ThreadWithMessages> create({
    required String email,
    String? name,
    String? subject,
    String? body,
    SupDeskLocale? locale,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/messages',
        ThreadWithMessages.fromJson,
        body: pruneNulls({
          'email': email,
          'name': name,
          'subject': subject,
          'body': body,
          'locale': locale?.value,
        }),
        options: options,
      );

  /// `PATCH /messages/:threadId`
  Future<ThreadWithMessages> update(
    String threadId, {
    ThreadStatus? status,
    String? subject,
    CallOptions? options,
  }) =>
      requestObject(
        'PATCH',
        '/messages/${encodePathSegment(threadId)}',
        ThreadWithMessages.fromJson,
        body: pruneNulls({'status': status?.value, 'subject': subject}),
        options: options,
      );

  /// `DELETE /messages/:threadId`
  Future<void> delete(String threadId, {CallOptions? options}) => requestEmpty(
        'DELETE',
        '/messages/${encodePathSegment(threadId)}',
        options: options,
      );

  /// `POST /messages/:threadId/messages` — appends a reply.
  Future<Message> addMessage(
    String threadId, {
    required String body,
    MessageSender? sender,
    SupDeskLocale? locale,
    CallOptions? options,
  }) =>
      requestObject(
        'POST',
        '/messages/${encodePathSegment(threadId)}/messages',
        Message.fromJson,
        body: pruneNulls({
          'body': body,
          'sender': sender?.value,
          'locale': locale?.value,
        }),
        options: options,
      );
}
