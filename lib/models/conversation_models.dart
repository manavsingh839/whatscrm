import 'contact_models.dart';

enum ConversationStatus {
  open,
  pending,
  closed;

  static ConversationStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return ConversationStatus.pending;
      case 'closed':
        return ConversationStatus.closed;
      case 'open':
      default:
        return ConversationStatus.open;
    }
  }

  String toDbValue() => name;
}

enum SenderType {
  customer,
  agent,
  bot;

  static SenderType fromString(String? sender) {
    switch (sender?.toLowerCase()) {
      case 'agent':
        return SenderType.agent;
      case 'bot':
        return SenderType.bot;
      case 'customer':
      default:
        return SenderType.customer;
    }
  }

  String toDbValue() => name;
}

enum MessageContentType {
  text,
  image,
  document,
  audio,
  video,
  location,
  template,
  interactive;

  static MessageContentType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'image':
        return MessageContentType.image;
      case 'document':
        return MessageContentType.document;
      case 'audio':
        return MessageContentType.audio;
      case 'video':
        return MessageContentType.video;
      case 'location':
        return MessageContentType.location;
      case 'template':
        return MessageContentType.template;
      case 'interactive':
        return MessageContentType.interactive;
      case 'text':
      default:
        return MessageContentType.text;
    }
  }

  String toDbValue() => name;
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  static MessageStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }

  String toDbValue() => name;
}

class InteractiveButton {
  final String replyId;
  final String title;

  InteractiveButton({required this.replyId, required this.title});

  factory InteractiveButton.fromJson(Map<String, dynamic> json) {
    return InteractiveButton(
      replyId: json['id'] as String? ?? json['reply_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': replyId, 'title': title};
}

class InteractiveListRow {
  final String replyId;
  final String title;
  final String? description;

  InteractiveListRow({
    required this.replyId,
    required this.title,
    this.description,
  });

  factory InteractiveListRow.fromJson(Map<String, dynamic> json) {
    return InteractiveListRow(
      replyId: json['id'] as String? ?? json['reply_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': replyId,
        'title': title,
        if (description != null) 'description': description,
      };
}

class InteractiveListSection {
  final String? title;
  final List<InteractiveListRow> rows;

  InteractiveListSection({this.title, required this.rows});

  factory InteractiveListSection.fromJson(Map<String, dynamic> json) {
    return InteractiveListSection(
      title: json['title'] as String?,
      rows: (json['rows'] as List<dynamic>?)
              ?.map((e) => InteractiveListRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        'rows': rows.map((e) => e.toJson()).toList(),
      };
}

class InteractiveMessagePayload {
  final String kind; // 'buttons' | 'list'
  final String text;
  final String? headerText;
  final String? footerText;
  final String? buttonLabel;
  final List<InteractiveButton> buttons;
  final List<InteractiveListSection> sections;

  InteractiveMessagePayload({
    required this.kind,
    required this.text,
    this.headerText,
    this.footerText,
    this.buttonLabel,
    this.buttons = const [],
    this.sections = const [],
  });

  factory InteractiveMessagePayload.fromJson(Map<String, dynamic> json) {
    return InteractiveMessagePayload(
      kind: json['kind'] as String? ?? 'buttons',
      text: json['text'] as String? ?? '',
      headerText: json['header_text'] as String?,
      footerText: json['footer_text'] as String?,
      buttonLabel: json['button_label'] as String?,
      buttons: (json['buttons'] as List<dynamic>?)
              ?.map((e) => InteractiveButton.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sections: (json['sections'] as List<dynamic>?)
              ?.map((e) => InteractiveListSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'text': text,
        if (headerText != null) 'header_text': headerText,
        if (footerText != null) 'footer_text': footerText,
        if (buttonLabel != null) 'button_label': buttonLabel,
        if (buttons.isNotEmpty) 'buttons': buttons.map((e) => e.toJson()).toList(),
        if (sections.isNotEmpty)
          'sections': sections.map((e) => e.toJson()).toList(),
      };
}

class Conversation {
  final String id;
  final String userId;
  final String contactId;
  final ConversationStatus status;
  final String? assignedAgentId;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Contact? contact;
  final bool aiAutoreplyDisabled;
  final int aiReplyCount;
  final String? aiHandoffSummary;

  Conversation({
    required this.id,
    required this.userId,
    required this.contactId,
    this.status = ConversationStatus.open,
    this.assignedAgentId,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.contact,
    this.aiAutoreplyDisabled = false,
    this.aiReplyCount = 0,
    this.aiHandoffSummary,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      contactId: json['contact_id'] as String? ?? '',
      status: ConversationStatus.fromString(json['status'] as String?),
      assignedAgentId: json['assigned_agent_id'] as String?,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      contact: json['contacts'] != null
          ? Contact.fromJson(json['contacts'] as Map<String, dynamic>)
          : json['contact'] != null
              ? Contact.fromJson(json['contact'] as Map<String, dynamic>)
              : null,
      aiAutoreplyDisabled: json['ai_autoreply_disabled'] as bool? ?? false,
      aiReplyCount: (json['ai_reply_count'] as num?)?.toInt() ?? 0,
      aiHandoffSummary: json['ai_handoff_summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'contact_id': contactId,
      'status': status.toDbValue(),
      if (assignedAgentId != null && assignedAgentId!.isNotEmpty)
        'assigned_agent_id': assignedAgentId,
      if (lastMessageText != null) 'last_message_text': lastMessageText,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'ai_autoreply_disabled': aiAutoreplyDisabled,
      'ai_reply_count': aiReplyCount,
      if (aiHandoffSummary != null) 'ai_handoff_summary': aiHandoffSummary,
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }

  Conversation copyWith({
    String? id,
    String? userId,
    String? contactId,
    ConversationStatus? status,
    String? assignedAgentId,
    String? lastMessageText,
    DateTime? lastMessageAt,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Contact? contact,
    bool? aiAutoreplyDisabled,
    int? aiReplyCount,
    String? aiHandoffSummary,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactId: contactId ?? this.contactId,
      status: status ?? this.status,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contact: contact ?? this.contact,
      aiAutoreplyDisabled: aiAutoreplyDisabled ?? this.aiAutoreplyDisabled,
      aiReplyCount: aiReplyCount ?? this.aiReplyCount,
      aiHandoffSummary: aiHandoffSummary ?? this.aiHandoffSummary,
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final SenderType senderType;
  final String? senderId;
  final MessageContentType contentType;
  final String? contentText;
  final String? mediaUrl;
  final String? mediaType;
  final String? templateName;
  final String? messageId;
  final MessageStatus status;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? interactiveReplyId;
  final InteractiveMessagePayload? interactivePayload;
  final bool aiGenerated;
  final int? errorCode;
  final String? errorTitle;
  final String? errorDetails;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderType,
    this.senderId,
    this.contentType = MessageContentType.text,
    this.contentText,
    this.mediaUrl,
    this.mediaType,
    this.templateName,
    this.messageId,
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.replyToMessageId,
    this.interactiveReplyId,
    this.interactivePayload,
    this.aiGenerated = false,
    this.errorCode,
    this.errorTitle,
    this.errorDetails,
  });

  bool get isOutbound => senderType == SenderType.agent || senderType == SenderType.bot;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderType: SenderType.fromString(json['sender_type'] as String?),
      senderId: json['sender_id'] as String?,
      contentType: MessageContentType.fromString(json['content_type'] as String?),
      contentText: json['content_text'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      templateName: json['template_name'] as String?,
      messageId: json['message_id'] as String?,
      status: MessageStatus.fromString(json['status'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      replyToMessageId: json['reply_to_message_id'] as String?,
      interactiveReplyId: json['interactive_reply_id'] as String?,
      interactivePayload: json['interactive_payload'] != null
          ? InteractiveMessagePayload.fromJson(
              json['interactive_payload'] as Map<String, dynamic>)
          : null,
      aiGenerated: json['ai_generated'] as bool? ?? false,
      errorCode: (json['error_code'] as num?)?.toInt(),
      errorTitle: json['error_title'] as String?,
      errorDetails: json['error_details'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_type': senderType.toDbValue(),
      'content_type': contentType.toDbValue(),
      if (contentText != null) 'content_text': contentText,
      if (mediaUrl != null && mediaUrl!.isNotEmpty) 'media_url': mediaUrl,
      if (mediaType != null && mediaType!.isNotEmpty) 'media_type': mediaType,
      if (templateName != null && templateName!.isNotEmpty) 'template_name': templateName,
      if (messageId != null && messageId!.isNotEmpty) 'message_id': messageId,
      'status': status.toDbValue(),
      'created_at': createdAt.toIso8601String(),
      if (replyToMessageId != null && replyToMessageId!.isNotEmpty)
        'reply_to_message_id': replyToMessageId,
      if (interactiveReplyId != null && interactiveReplyId!.isNotEmpty)
        'interactive_reply_id': interactiveReplyId,
      if (interactivePayload != null)
        'interactive_payload': interactivePayload?.toJson(),
      'ai_generated': aiGenerated,
      if (errorCode != null) 'error_code': errorCode,
      if (errorTitle != null) 'error_title': errorTitle,
      if (errorDetails != null) 'error_details': errorDetails,
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (senderId != null && senderId!.trim().isNotEmpty) {
      map['sender_id'] = senderId!.trim();
    }
    return map;
  }
}

class MessageReaction {
  final String id;
  final String messageId;
  final String conversationId;
  final String actorType; // 'customer' | 'agent'
  final String? actorId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.actorType,
    this.actorId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      actorType: json['actor_type'] as String? ?? 'agent',
      actorId: json['actor_id'] as String?,
      emoji: json['emoji'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'conversation_id': conversationId,
      'actor_type': actorType,
      'actor_id': actorId,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
