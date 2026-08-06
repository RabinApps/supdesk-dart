// Timeouts, cancellation, retries, and a Dio of your own.
//
//   SUPDESK_API_KEY=sd_live_… dart run bin/resilience.dart
import 'dart:async';
import 'dart:io';

// supdesk re-exports Dio, CancelToken and DioException, so most code needs only
// the one import. Reaching further into dio — BaseOptions, interceptors — means
// depending on it directly, which is deliberate: the SDK does not hide dio, it
// just does not re-export all of it.
import 'package:dio/dio.dart';
import 'package:supdesk/supdesk.dart';

Future<void> main() async {
  final apiKey = _env('SUPDESK_API_KEY');

  // A Dio you configure and own. The SDK will not close it — that is yours to
  // do — and it applies its own per-request options on top, so `validateStatus`
  // and the response type stay under the SDK's control either way.
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          stderr.writeln('→ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          stderr.writeln('← ${response.statusCode} ${response.realUri.path}');
          handler.next(response);
        },
      ),
    );

  final supdesk = SupDesk(
    apiKey: apiKey,
    dio: dio,
    // The deadline for a whole request, retries excluded.
    timeout: const Duration(seconds: 10),
    // Retries after the first attempt. 0 disables retrying entirely.
    maxRetries: 3,
    // Off by default, and worth leaving off: SupDesk has no idempotency key,
    // and a replayed `submissions.create` would file the user's ticket twice
    // and charge your quota twice. Turn it on only for a workload where a
    // duplicate is cheaper than a dropped write.
    retryUnsafeMethods: false,
    defaultHeaders: {'x-app': 'billing-worker'},
  );

  try {
    // A per-call timeout overrides the client one. Duration.zero disables it.
    await supdesk.articles.list(
      options: const CallOptions(timeout: Duration(seconds: 2)),
    );

    // Cancellation is dio's CancelToken. The SDK deliberately does not wrap the
    // resulting error: a cancelled request is your own doing, not a SupDesk
    // failure, so it arrives as DioException with type `cancel`.
    final token = CancelToken();
    Timer(const Duration(milliseconds: 50), () => token.cancel('too slow'));

    try {
      await supdesk.submissions.list(options: CallOptions(cancelToken: token));
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        print('cancelled: ${error.error}');
      } else {
        rethrow;
      }
    }

    // One token can cancel a whole fan-out.
    final batch = CancelToken();
    final options = CallOptions(cancelToken: batch);
    final results =
        await Future.wait([
          supdesk.articles.list(options: options),
          supdesk.articleCategories.list(options: options),
        ]).onError<DioException>((error, _) {
          batch.cancel('a sibling request failed');
          throw error;
        });
    print('fetched ${results.length} lists');
  } on LimitReachedException catch (error) {
    // Shares HTTP 429 with rate limiting but means the opposite: the monthly
    // quota is gone, and no amount of backoff will bring it back. The SDK never
    // retries this one.
    print('quota exhausted: ${error.message}');
  } on RateLimitedException catch (error) {
    // Already retried up to `maxRetries` with backoff, honouring Retry-After.
    // Reaching here means the window never opened.
    print('still throttled after retries: ${error.header('retry-after')}');
  } on SupDeskTimeoutException catch (error) {
    // Never retried: you chose the deadline, and spending it several times over
    // defeats the point.
    print('gave up after ${error.timeout.inSeconds}s');
  } on SupDeskConnectionException catch (error) {
    print('could not reach SupDesk: ${error.cause}');
  } on SupDeskApiException catch (error) {
    print('${error.statusCode} ${error.code}: ${error.message}');
    print('request id: ${error.requestId ?? 'none'}');
  } finally {
    // A no-op for an injected Dio. Close the one you made yourself.
    supdesk.close();
    dio.close();
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
