// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

/// Standalone Dart Webhook Server for Meta WhatsApp Cloud API
/// Receives inbound messages, delivery statuses, and template updates.
///
/// Run locally or deploy via Docker:
///   dart run server/webhook_server.dart
void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? 'https://your-project.supabase.co';
  final supabaseServiceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
  final metaAppSecret = Platform.environment['META_APP_SECRET'] ?? '';
  final verifyToken = Platform.environment['WHATSAPP_VERIFY_TOKEN'] ?? 'wacrm_verify_token';

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('====================================================');
  print('🚀 WhatsApp CRM Meta Webhook Server running on port $port');
  print('   Endpoint: http://localhost:$port/api/whatsapp/webhook');
  print('====================================================');

  await for (HttpRequest request in server) {
    handleRequest(
      request,
      supabaseUrl: supabaseUrl,
      serviceKey: supabaseServiceKey,
      metaAppSecret: metaAppSecret,
      verifyToken: verifyToken,
    );
  }
}

Future<void> handleRequest(
  HttpRequest request, {
  required String supabaseUrl,
  required String serviceKey,
  required String metaAppSecret,
  required String verifyToken,
}) async {
  final path = request.uri.path;

  // Health check
  if (path == '/health' || path == '/') {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'status': 'ok', 'service': 'wacrm-webhook-server'}))
      ..close();
    return;
  }

  if (path == '/api/whatsapp/webhook') {
    if (request.method == 'GET') {
      // 1. Meta Webhook Verification Challenge
      final mode = request.uri.queryParameters['hub.mode'];
      final token = request.uri.queryParameters['hub.verify_token'];
      final challenge = request.uri.queryParameters['hub.challenge'];

      if (mode == 'subscribe' && token == verifyToken && challenge != null) {
        print('✅ Webhook verified successfully by Meta challenge!');
        request.response
          ..statusCode = HttpStatus.ok
          ..write(challenge)
          ..close();
        return;
      } else {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('Verification token mismatch')
          ..close();
        return;
      }
    } else if (request.method == 'POST') {
      // 2. Meta Inbound Event Notification
      final rawBody = await utf8.decoder.bind(request).join();
      final sigHeader = request.headers.value('x-hub-signature-256');

      // Verify HMAC signature if secret is configured
      if (metaAppSecret.isNotEmpty && sigHeader != null) {
        final hmac = crypto.Hmac(crypto.sha256, utf8.encode(metaAppSecret));
        final expected = 'sha256=${hmac.convert(utf8.encode(rawBody))}';
        if (sigHeader != expected) {
          print('❌ Rejected webhook: HMAC-SHA256 signature mismatch');
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..write('Signature mismatch')
            ..close();
          return;
        }
      }

      // Process event payload asynchronously
      try {
        final payload = jsonDecode(rawBody) as Map<String, dynamic>;
        processWebhookPayload(payload, supabaseUrl: supabaseUrl, serviceKey: serviceKey);
      } catch (e) {
        print('Error parsing webhook payload: $e');
      }

      // Always acknowledge Meta with 200 OK immediately
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'received'}))
        ..close();
      return;
    }
  }

  request.response
    ..statusCode = HttpStatus.notFound
    ..write('Not found')
    ..close();
}

Future<void> processWebhookPayload(
  Map<String, dynamic> payload, {
  required String supabaseUrl,
  required String serviceKey,
}) async {
  final entries = payload['entry'] as List? ?? [];
  for (final entry in entries) {
    final changes = entry['changes'] as List? ?? [];
    for (final change in changes) {
      final value = change['value'] as Map<String, dynamic>? ?? {};

      // A. Message Status Updates (sent, delivered, read, failed)
      final statuses = value['statuses'] as List? ?? [];
      for (final s in statuses) {
        final wamid = s['id'] as String?;
        final status = s['status'] as String?;
        print('📩 Delivery Status Update: $wamid -> $status');

        if (wamid != null && status != null && serviceKey.isNotEmpty) {
          await http.patch(
            Uri.parse('$supabaseUrl/rest/v1/messages?message_id=eq.$wamid'),
            headers: {
              'apikey': serviceKey,
              'Authorization': 'Bearer $serviceKey',
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: jsonEncode({'status': status}),
          );
        }
      }

      // B. Inbound Customer Messages
      final messages = value['messages'] as List? ?? [];
      final contacts = value['contacts'] as List? ?? [];
      String contactName = '';
      if (contacts.isNotEmpty) {
        contactName = contacts[0]['profile']?['name'] ?? '';
      }

      for (final msg in messages) {
        final fromPhone = msg['from'] as String? ?? '';
        final msgType = msg['type'] as String? ?? 'text';
        String textContent = '';

        if (msgType == 'text') {
          textContent = msg['text']?['body'] ?? '';
        } else if (msgType == 'interactive') {
          textContent = msg['interactive']?['button_reply']?['title'] ??
              msg['interactive']?['list_reply']?['title'] ??
              'Interactive reply';
        } else {
          textContent = '[$msgType attachment]';
        }

        print('💬 Inbound Message from $fromPhone ($contactName): "$textContent"');
      }
    }
  }
}
