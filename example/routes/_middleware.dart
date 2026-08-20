import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:supdesk/supdesk.dart';

// One client for the whole process. It is cheap to hold and it owns a Dio
// instance with a connection pool, so building one per request would throw that
// pool away every time.
final _supdesk = SupDesk(apiKey: Platform.environment['SUPDESK_API_KEY'] ?? '');

Handler middleware(Handler handler) => handler
    .use(requestLogger())
    .use(provider<SupDesk>((_) => _supdesk))
    .use(_catchSupDeskErrors);

/// Turns SupDesk failures into sensible HTTP responses.
///
/// Every failure this SDK raises shares one base class, so a single middleware
/// covers the lot while the specific cases still get their own status.
Middleware get _catchSupDeskErrors =>
    (handler) => (context) async {
      try {
        return await handler(context);
      } on LimitReachedException {
        // The monthly quota is gone; backing off will not help.
        return Response(
          statusCode: HttpStatus.serviceUnavailable,
          body: 'SupDesk quota exhausted.',
        );
      } on RateLimitedException {
        return Response(
          statusCode: HttpStatus.tooManyRequests,
          body: 'Slow down.',
        );
      } on SupDeskApiException catch (error) {
        return Response(
          statusCode: HttpStatus.badGateway,
          body: 'SupDesk said ${error.statusCode} ${error.code}.',
        );
      } on SupDeskException catch (error) {
        return Response(statusCode: HttpStatus.badGateway, body: error.message);
      }
    };
