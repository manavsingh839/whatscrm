import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_models.dart';
import '../models/whatsapp_models.dart';

class MetaApiService {
  static const String apiVersion = 'v21.0';
  static const String baseUrl = 'https://graph.facebook.com/$apiVersion';

  /// Verify Meta phone number ID and fetch public info
  static Future<Map<String, dynamic>> verifyPhoneNumber({
    required String phoneNumberId,
    required String accessToken,
  }) async {
    final url = Uri.parse(
        '$baseUrl/$phoneNumberId?fields=id,display_phone_number,verified_name,quality_rating');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Meta API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Send outbound text message to a WhatsApp user
  static Future<String> sendTextMessage({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String text,
    String? replyToMessageId,
  }) async {
    final url = Uri.parse('$baseUrl/$phoneNumberId/messages');
    final body = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'text',
      'text': {'body': text},
      if (replyToMessageId != null) 'context': {'message_id': replyToMessageId},
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resData = jsonDecode(response.body);
      final messages = resData['messages'] as List?;
      if (messages != null && messages.isNotEmpty) {
        return messages[0]['id'] as String;
      }
      return '';
    } else {
      throw Exception('Failed to send WhatsApp message: ${response.body}');
    }
  }

  /// Send interactive reply buttons (1 to 3 buttons)
  static Future<String> sendInteractiveButtons({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String bodyText,
    String? headerText,
    String? footerText,
    required List<InteractiveButton> buttons,
  }) async {
    final url = Uri.parse('$baseUrl/$phoneNumberId/messages');
    final interactivePayload = {
      'type': 'button',
      if (headerText != null) 'header': {'type': 'text', 'text': headerText},
      'body': {'text': bodyText},
      if (footerText != null) 'footer': {'text': footerText},
      'action': {
        'buttons': buttons.map((b) => {
          'type': 'reply',
          'reply': {'id': b.replyId, 'title': b.title},
        }).toList(),
      },
    };

    final body = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': interactivePayload,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resData = jsonDecode(response.body);
      return resData['messages']?[0]?['id'] ?? '';
    } else {
      throw Exception('Failed to send interactive buttons: ${response.body}');
    }
  }

  /// Send interactive list menu (up to 10 rows)
  static Future<String> sendInteractiveList({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String bodyText,
    required String buttonLabel,
    String? headerText,
    String? footerText,
    required List<InteractiveListSection> sections,
  }) async {
    final url = Uri.parse('$baseUrl/$phoneNumberId/messages');
    final interactivePayload = {
      'type': 'list',
      if (headerText != null) 'header': {'type': 'text', 'text': headerText},
      'body': {'text': bodyText},
      if (footerText != null) 'footer': {'text': footerText},
      'action': {
        'button': buttonLabel,
        'sections': sections.map((s) => {
          if (s.title != null) 'title': s.title,
          'rows': s.rows.map((r) => {
            'id': r.replyId,
            'title': r.title,
            if (r.description != null) 'description': r.description,
          }).toList(),
        }).toList(),
      },
    };

    final body = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'interactive',
      'interactive': interactivePayload,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resData = jsonDecode(response.body);
      return resData['messages']?[0]?['id'] ?? '';
    } else {
      throw Exception('Failed to send interactive list: ${response.body}');
    }
  }

  /// Send media message (image, video, document, audio)
  static Future<String> sendMediaMessage({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String mediaType, // 'image', 'video', 'document', 'audio'
    required String mediaUrl,
    String? caption,
    String? filename,
  }) async {
    final url = Uri.parse('$baseUrl/$phoneNumberId/messages');
    final mediaObject = {
      'link': mediaUrl,
      if (caption != null && (mediaType == 'image' || mediaType == 'video' || mediaType == 'document'))
        'caption': caption,
      if (filename != null && mediaType == 'document') 'filename': filename,
    };

    final body = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': mediaType,
      mediaType: mediaObject,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resData = jsonDecode(response.body);
      return resData['messages']?[0]?['id'] ?? '';
    } else {
      throw Exception('Failed to send media message: ${response.body}');
    }
  }

  /// Send Meta approved template message
  static Future<String> sendTemplateMessage({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String templateName,
    required String languageCode,
    List<String> bodyVariables = const [],
    String? headerMediaUrl,
  }) async {
    final url = Uri.parse('$baseUrl/$phoneNumberId/messages');

    final List<Map<String, dynamic>> components = [];

    if (headerMediaUrl != null) {
      components.add({
        'type': 'header',
        'parameters': [
          {'type': 'image', 'image': {'link': headerMediaUrl}}
        ],
      });
    }

    if (bodyVariables.isNotEmpty) {
      components.add({
        'type': 'body',
        'parameters': bodyVariables.map((v) => {'type': 'text', 'text': v}).toList(),
      });
    }

    final body = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': to,
      'type': 'template',
      'template': {
        'name': templateName,
        'language': {'code': languageCode},
        if (components.isNotEmpty) 'components': components,
      },
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resData = jsonDecode(response.body);
      return resData['messages']?[0]?['id'] ?? '';
    } else {
      throw Exception('Failed to send template message: ${response.body}');
    }
  }

  /// Mark message as read
  static Future<void> markAsRead({
    required String phoneNumberId,
    required String accessToken,
    required String messageId,
  }) async {
    final url = Uri.parse('$baseUrl/$phoneNumberId/messages');
    await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'messaging_product': 'whatsapp',
        'status': 'read',
        'message_id': messageId,
      }),
    );
  }

  /// Send emoji reaction to a message
  static Future<void> sendReaction({
    required String phoneNumberId,
    required String accessToken,
    required String to,
    required String messageId,
    required String emoji,
  }) async {
    final url = Uri.parse('$baseUrl/$phoneNumberId/messages');
    await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': to,
        'type': 'reaction',
        'reaction': {
          'message_id': messageId,
          'emoji': emoji,
        },
      }),
    );
  }

  /// Fetch message templates from WABA
  static Future<List<MessageTemplate>> fetchWabaTemplates({
    required String wabaId,
    required String accessToken,
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/$wabaId/message_templates?limit=100');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final rawList = data['data'] as List? ?? [];

      return rawList.map((item) {
        String body = '';
        String? footer;
        String? headerType;
        String? headerContent;
        List<TemplateButtonConfig> buttons = [];

        final components = item['components'] as List? ?? [];
        for (final c in components) {
          final type = c['type'];
          if (type == 'BODY') {
            body = c['text'] ?? '';
          } else if (type == 'FOOTER') {
            footer = c['text'];
          } else if (type == 'HEADER') {
            headerType = (c['format'] as String?)?.toLowerCase();
            headerContent = c['text'];
          } else if (type == 'BUTTONS') {
            final btnList = c['buttons'] as List? ?? [];
            for (final b in btnList) {
              buttons.add(TemplateButtonConfig(
                type: b['type'] ?? 'QUICK_REPLY',
                text: b['text'] ?? '',
                url: b['url'],
                phoneNumber: b['phone_number'],
              ));
            }
          }
        }

        return MessageTemplate(
          id: '',
          userId: userId,
          name: item['name'] ?? '',
          category: item['category'] ?? 'Utility',
          language: item['language'] ?? 'en',
          headerType: headerType,
          headerContent: headerContent,
          bodyText: body,
          footerText: footer,
          buttons: buttons,
          status: item['status'] ?? 'APPROVED',
          metaTemplateId: item['id']?.toString(),
          createdAt: DateTime.now(),
        );
      }).toList();
    } else {
      throw Exception('Failed to fetch templates: ${response.body}');
    }
  }
}
