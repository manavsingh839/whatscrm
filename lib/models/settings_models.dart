class ApiKey {
  final String id;
  final String accountId;
  final String userId;
  final String name;
  final String prefix;
  final List<String> scopes;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  ApiKey({
    required this.id,
    required this.accountId,
    required this.userId,
    required this.name,
    required this.prefix,
    this.scopes = const [],
    this.lastUsedAt,
    required this.createdAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      prefix: json['prefix'] as String? ?? '',
      scopes: (json['scopes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WebhookEndpoint {
  final String id;
  final String accountId;
  final String userId;
  final String url;
  final String? secret;
  final List<String> events;
  final bool isActive;
  final int failureCount;
  final String? lastError;
  final DateTime createdAt;

  WebhookEndpoint({
    required this.id,
    required this.accountId,
    required this.userId,
    required this.url,
    this.secret,
    this.events = const [],
    this.isActive = true,
    this.failureCount = 0,
    this.lastError,
    required this.createdAt,
  });

  factory WebhookEndpoint.fromJson(Map<String, dynamic> json) {
    return WebhookEndpoint(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      secret: json['secret'] as String?,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: json['is_active'] as bool? ?? true,
      failureCount: (json['failure_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'user_id': userId,
      'url': url,
      'secret': secret,
      'events': events,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AiConfig {
  final String id;
  final String accountId;
  final String provider; // 'openai' | 'anthropic'
  final String model;
  final String? apiKeyEncrypted;
  final String systemPrompt;
  final double temperature;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiConfig({
    required this.id,
    required this.accountId,
    this.provider = 'openai',
    this.model = 'gpt-4o-mini',
    this.apiKeyEncrypted,
    this.systemPrompt = 'You are a helpful customer support agent.',
    this.temperature = 0.7,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      provider: json['provider'] as String? ?? 'openai',
      model: json['model'] as String? ?? 'gpt-4o-mini',
      apiKeyEncrypted: json['api_key_encrypted'] as String?,
      systemPrompt: json['system_prompt'] as String? ??
          'You are a helpful customer support agent.',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'provider': provider,
      'model': model,
      if (apiKeyEncrypted != null && apiKeyEncrypted!.isNotEmpty)
        'api_key_encrypted': apiKeyEncrypted,
      'system_prompt': systemPrompt,
      'temperature': temperature,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) {
      map['id'] = id.trim();
    }
    if (accountId.trim().isNotEmpty) {
      map['account_id'] = accountId.trim();
    }
    return map;
  }
}

class AiKnowledgeDocument {
  final String id;
  final String accountId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiKnowledgeDocument({
    required this.id,
    required this.accountId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiKnowledgeDocument.fromJson(Map<String, dynamic> json) {
    return AiKnowledgeDocument(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
