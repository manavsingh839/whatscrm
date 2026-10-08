import 'conversation_models.dart';

class WhatsAppConfig {
  final String id;
  final String userId;
  final String phoneNumberId;
  final String? wabaId;
  final String accessToken;
  final String? verifyToken;
  final String status; // 'connected' | 'disconnected'
  final DateTime? connectedAt;
  final DateTime? registeredAt;
  final DateTime? subscribedAppsAt;
  final String? lastRegistrationError;
  final bool mirrorInboundMedia;

  WhatsAppConfig({
    required this.id,
    required this.userId,
    required this.phoneNumberId,
    this.wabaId,
    required this.accessToken,
    this.verifyToken,
    this.status = 'disconnected',
    this.connectedAt,
    this.registeredAt,
    this.subscribedAppsAt,
    this.lastRegistrationError,
    this.mirrorInboundMedia = true,
  });

  bool get isConnected => status == 'connected';

  factory WhatsAppConfig.fromJson(Map<String, dynamic> json) {
    return WhatsAppConfig(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      phoneNumberId: json['phone_number_id'] as String? ?? '',
      wabaId: json['waba_id'] as String?,
      accessToken: json['access_token'] as String? ?? '',
      verifyToken: json['verify_token'] as String?,
      status: json['status'] as String? ?? 'disconnected',
      connectedAt: json['connected_at'] != null
          ? DateTime.tryParse(json['connected_at'] as String)
          : null,
      registeredAt: json['registered_at'] != null
          ? DateTime.tryParse(json['registered_at'] as String)
          : null,
      subscribedAppsAt: json['subscribed_apps_at'] != null
          ? DateTime.tryParse(json['subscribed_apps_at'] as String)
          : null,
      lastRegistrationError: json['last_registration_error'] as String?,
      mirrorInboundMedia: json['mirror_inbound_media'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'phone_number_id': phoneNumberId,
      if (wabaId != null && wabaId!.isNotEmpty) 'waba_id': wabaId,
      'access_token': accessToken,
      if (verifyToken != null && verifyToken!.isNotEmpty) 'verify_token': verifyToken,
      'status': status,
      if (connectedAt != null) 'connected_at': connectedAt?.toIso8601String(),
      if (registeredAt != null) 'registered_at': registeredAt?.toIso8601String(),
      if (subscribedAppsAt != null) 'subscribed_apps_at': subscribedAppsAt?.toIso8601String(),
      if (lastRegistrationError != null) 'last_registration_error': lastRegistrationError,
      'mirror_inbound_media': mirrorInboundMedia,
    };
    if (id.trim().isNotEmpty) {
      map['id'] = id.trim();
    }
    if (userId.trim().isNotEmpty) {
      map['user_id'] = userId.trim();
    }
    return map;
  }
}

class TemplateButtonConfig {
  final String type; // 'QUICK_REPLY' | 'URL' | 'PHONE_NUMBER' | 'COPY_CODE'
  final String text;
  final String? url;
  final String? phoneNumber;
  final String? example;

  TemplateButtonConfig({
    required this.type,
    required this.text,
    this.url,
    this.phoneNumber,
    this.example,
  });

  factory TemplateButtonConfig.fromJson(Map<String, dynamic> json) {
    return TemplateButtonConfig(
      type: json['type'] as String? ?? 'QUICK_REPLY',
      text: json['text'] as String? ?? '',
      url: json['url'] as String?,
      phoneNumber: json['phone_number'] as String?,
      example: json['example'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        if (url != null) 'url': url,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (example != null) 'example': example,
      };
}

class MessageTemplate {
  final String id;
  final String userId;
  final String name;
  final String category; // 'Marketing' | 'Utility' | 'Authentication'
  final String language;
  final String? headerType; // 'text' | 'image' | 'video' | 'document'
  final String? headerContent;
  final String? headerHandle;
  final String? headerMediaUrl;
  final String bodyText;
  final String? footerText;
  final List<TemplateButtonConfig> buttons;
  final Map<String, dynamic>? sampleValues;
  final String status; // 'DRAFT' | 'PENDING' | 'APPROVED' | 'REJECTED' | 'PAUSED' | 'DISABLED'
  final String? metaTemplateId;
  final String? rejectionReason;
  final String? qualityScore;
  final String? submissionError;
  final DateTime? lastSubmittedAt;
  final DateTime createdAt;

  MessageTemplate({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    this.language = 'en',
    this.headerType,
    this.headerContent,
    this.headerHandle,
    this.headerMediaUrl,
    required this.bodyText,
    this.footerText,
    this.buttons = const [],
    this.sampleValues,
    this.status = 'DRAFT',
    this.metaTemplateId,
    this.rejectionReason,
    this.qualityScore,
    this.submissionError,
    this.lastSubmittedAt,
    required this.createdAt,
  });

  bool get isApproved => status.toUpperCase() == 'APPROVED';

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Marketing',
      language: json['language'] as String? ?? 'en',
      headerType: json['header_type'] as String?,
      headerContent: json['header_content'] as String?,
      headerHandle: json['header_handle'] as String?,
      headerMediaUrl: json['header_media_url'] as String?,
      bodyText: json['body_text'] as String? ?? '',
      footerText: json['footer_text'] as String?,
      buttons: (json['buttons'] as List<dynamic>?)
              ?.map((e) => TemplateButtonConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sampleValues: json['sample_values'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'DRAFT',
      metaTemplateId: json['meta_template_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      qualityScore: json['quality_score'] as String?,
      submissionError: json['submission_error'] as String?,
      lastSubmittedAt: json['last_submitted_at'] != null
          ? DateTime.tryParse(json['last_submitted_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'category': category,
      'language': language,
      if (headerType != null) 'header_type': headerType,
      if (headerContent != null) 'header_content': headerContent,
      if (headerHandle != null) 'header_handle': headerHandle,
      if (headerMediaUrl != null) 'header_media_url': headerMediaUrl,
      'body_text': bodyText,
      if (footerText != null) 'footer_text': footerText,
      if (buttons.isNotEmpty) 'buttons': buttons.map((e) => e.toJson()).toList(),
      if (sampleValues != null) 'sample_values': sampleValues,
      'status': status,
      if (metaTemplateId != null) 'meta_template_id': metaTemplateId,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (qualityScore != null) 'quality_score': qualityScore,
      if (submissionError != null) 'submission_error': submissionError,
      if (lastSubmittedAt != null)
        'last_submitted_at': lastSubmittedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }
}

class QuickReply {
  final String id;
  final String accountId;
  final String userId;
  final String title;
  final String kind; // 'text' | 'interactive'
  final String? contentText;
  final InteractiveMessagePayload? interactivePayload;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuickReply({
    required this.id,
    required this.accountId,
    required this.userId,
    required this.title,
    required this.kind,
    this.contentText,
    this.interactivePayload,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      kind: json['kind'] as String? ?? 'text',
      contentText: json['content_text'] as String?,
      interactivePayload: json['interactive_payload'] != null
          ? InteractiveMessagePayload.fromJson(
              json['interactive_payload'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title.trim(),
      'kind': kind,
      if (contentText != null) 'content_text': contentText,
      if (interactivePayload != null)
        'interactive_payload': interactivePayload?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (accountId.trim().isNotEmpty) map['account_id'] = accountId.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }
}
