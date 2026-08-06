import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) => Response.json(
  body: {
    'routes': [
      'POST /feedback',
      'GET  /submissions?status=open',
      'POST /webhooks/supdesk',
    ],
  },
);
