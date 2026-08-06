import 'package:dio/dio.dart' show CancelToken;

import '../core/errors.dart';
import '../core/http.dart';
import '../core/pagination.dart';
import '../models/json.dart';

/// Per-call overrides available on every resource method.
class CallOptions {
  /// Creates per-call overrides.
  const CallOptions({this.timeout, this.headers, this.cancelToken});

  /// Overrides the client-level timeout. [Duration.zero] disables it.
  final Duration? timeout;

  /// Extra headers for this request only. `authorization` cannot be replaced.
  final Map<String, String>? headers;

  /// Cancels the request. dio's equivalent of an `AbortSignal`.
  final CancelToken? cancelToken;
}

/// Shared plumbing for resource classes.
///
/// Every SupDesk read wraps its payload in `{ data: … }` and every list adds
/// `{ pagination: … }`, so unwrapping and paging live here rather than being
/// repeated across nine resources.
abstract class APIResource {
  /// Binds the resource to a transport.
  APIResource(this.client);

  /// The transport every method on this resource issues requests through.
  final SupDeskHttpClient client;

  /// Issues a request and decodes the `data` object.
  Future<T> requestObject<T>(
    String method,
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, Object?>? query,
    Object? body,
    CallOptions? options,
  }) async {
    final response = await _send(method, path, query, body, options);
    final data = _dataOf(response);

    if (data is! Map<String, dynamic>) {
      throw _malformed('an object');
    }

    return fromJson(data);
  }

  /// Issues a request and decodes the `data` array.
  Future<List<T>> requestList<T>(
    String method,
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, Object?>? query,
    Object? body,
    CallOptions? options,
  }) async {
    final response = await _send(method, path, query, body, options);
    final data = _dataOf(response);

    if (data is! List) {
      throw _malformed('an array');
    }

    return objectList(data).map(fromJson).toList(growable: false);
  }

  /// Issues a request that returns no content.
  Future<void> requestEmpty(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    CallOptions? options,
  }) =>
      _send(method, path, query, body, options);

  /// Fetches the first page of a list endpoint as an auto-paging [Page].
  Future<Page<T>> listPage<T>(
    String path,
    Map<String, Object?> params,
    T Function(Map<String, dynamic>) fromJson, {
    CallOptions? options,
  }) {
    late final PageFetcher<T> fetchPage;

    fetchPage = (query) async {
      final response = await _send('GET', path, query, null, options);

      if (response is! Map<String, dynamic>) {
        throw _malformed('a paginated envelope');
      }

      final items =
          objectList(response['data']).map(fromJson).toList(growable: false);
      final pagination = objectOrNull(response['pagination']);

      return Page<T>(
        data: items,
        pagination: pagination == null
            ? PaginationMeta(limit: items.length, offset: 0, hasMore: false)
            : PaginationMeta.fromJson(pagination),
        fetchPage: fetchPage,
        params: query,
      );
    };

    return fetchPage(params);
  }

  Future<Object?> _send(
    String method,
    String path,
    Map<String, Object?>? query,
    Object? body,
    CallOptions? options,
  ) =>
      client.request(
        method: method,
        path: path,
        query: query,
        body: body,
        headers: options?.headers,
        timeout: options?.timeout,
        cancelToken: options?.cancelToken,
      );

  Object? _dataOf(Object? response) =>
      response is Map<String, dynamic> ? response['data'] : null;

  SupDeskApiException _malformed(String expected) => SupDeskApiException(
        statusCode: 200,
        code: SupDeskErrorCode.internalError,
        message: 'The SupDesk response did not contain $expected under `data`.',
      );
}
