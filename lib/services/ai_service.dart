import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_models.dart';
import '../models/settings_models.dart';

class AiService {
  /// Generate smart reply suggestion using OpenAI or Anthropic
  static Future<String> generateDraftReply({
    required AiConfig config,
    required String apiKey,
    required List<Message> conversationHistory,
    String? contactName,
    String? knowledgeContext,
  }) async {
    final messagesContext = conversationHistory.take(20).map((m) {
      final role = m.isOutbound ? 'assistant' : 'user';
      return {'role': role, 'content': m.contentText ?? '[Media Message]'};
    }).toList();

    final systemPrompt = '''
${config.systemPrompt}

You are assisting a customer named "${contactName ?? 'Customer'}".
${knowledgeContext != null && knowledgeContext.isNotEmpty ? 'Reference Knowledge Base:\n$knowledgeContext\n' : ''}
Draft a polite, concise, and helpful response for WhatsApp.
''';

    if (config.provider.toLowerCase() == 'anthropic') {
      return await _callAnthropic(
        apiKey: apiKey,
        model: config.model.isNotEmpty ? config.model : 'claude-3-5-sonnet-20241022',
        systemPrompt: systemPrompt,
        messages: messagesContext,
        temperature: config.temperature,
      );
    } else {
      // Default OpenAI
      return await _callOpenAi(
        apiKey: apiKey,
        model: config.model.isNotEmpty ? config.model : 'gpt-4o-mini',
        systemPrompt: systemPrompt,
        messages: messagesContext,
        temperature: config.temperature,
      );
    }
  }

  static Future<String> _callOpenAi({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required double temperature,
  }) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final payload = {
      'model': model,
      'temperature': temperature,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ],
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content']?.trim() ?? '';
    } else {
      throw Exception('OpenAI API error: ${response.body}');
    }
  }

  static Future<String> _callAnthropic({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required double temperature,
  }) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');
    final payload = {
      'model': model,
      'max_tokens': 1024,
      'temperature': temperature,
      'system': systemPrompt,
      'messages': messages,
    };

    final response = await http.post(
      url,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final content = data['content'] as List?;
      if (content != null && content.isNotEmpty) {
        return content[0]['text']?.trim() ?? '';
      }
      return '';
    } else {
      throw Exception('Anthropic API error: ${response.body}');
    }
  }
}
