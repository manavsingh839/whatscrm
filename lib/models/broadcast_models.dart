import 'contact_models.dart';

enum BroadcastStatus {
  draft,
  scheduled,
  sending,
  sent,
  failed;

  static BroadcastStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'scheduled':
        return BroadcastStatus.scheduled;
      case 'sending':
        return BroadcastStatus.sending;
      case 'sent':
        return BroadcastStatus.sent;
      case 'failed':
        return BroadcastStatus.failed;
      case 'draft':
      default:
        return BroadcastStatus.draft;
    }
  }

  String toDbValue() => name;
}

enum RecipientStatus {
  pending,
  sent,
  delivered,
  read,
  replied,
  failed;

  static RecipientStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'sent':
        return RecipientStatus.sent;
      case 'delivered':
        return RecipientStatus.delivered;
      case 'read':
        return RecipientStatus.read;
      case 'replied':
        return RecipientStatus.replied;
      case 'failed':
        return RecipientStatus.failed;
      case 'pending':
      default:
        return RecipientStatus.pending;
    }
  }

  String toDbValue() => name;
}

class Broadcast {
  final String id;
  final String userId;
  final String name;
  final String templateName;
  final String templateLanguage;
  final Map<String, dynamic>? templateVariables;
  final Map<String, dynamic>? audienceFilter;
  final DateTime? scheduledAt;
  final BroadcastStatus status;
  final int totalRecipients;
  final int sentCount;
  final int deliveredCount;
  final int readCount;
  final int repliedCount;
  final int failedCount;
  final DateTime? deliveryLockedAt;
  final DateTime createdAt;

  Broadcast({
    required this.id,
    required this.userId,
    required this.name,
    required this.templateName,
    this.templateLanguage = 'en',
    this.templateVariables,
    this.audienceFilter,
    this.scheduledAt,
    this.status = BroadcastStatus.draft,
    this.totalRecipients = 0,
    this.sentCount = 0,
    this.deliveredCount = 0,
    this.readCount = 0,
    this.repliedCount = 0,
    this.failedCount = 0,
    this.deliveryLockedAt,
    required this.createdAt,
  });

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      templateLanguage: json['template_language'] as String? ?? 'en',
      templateVariables: json['template_variables'] as Map<String, dynamic>?,
      audienceFilter: json['audience_filter'] as Map<String, dynamic>?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'] as String)
          : null,
      status: BroadcastStatus.fromString(json['status'] as String?),
      totalRecipients: (json['total_recipients'] as num?)?.toInt() ?? 0,
      sentCount: (json['sent_count'] as num?)?.toInt() ?? 0,
      deliveredCount: (json['delivered_count'] as num?)?.toInt() ?? 0,
      readCount: (json['read_count'] as num?)?.toInt() ?? 0,
      repliedCount: (json['replied_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      deliveryLockedAt: json['delivery_locked_at'] != null
          ? DateTime.tryParse(json['delivery_locked_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'template_name': templateName,
      'template_language': templateLanguage,
      if (templateVariables != null) 'template_variables': templateVariables,
      if (audienceFilter != null) 'audience_filter': audienceFilter,
      if (scheduledAt != null) 'scheduled_at': scheduledAt?.toIso8601String(),
      'status': status.toDbValue(),
      'total_recipients': totalRecipients,
      'sent_count': sentCount,
      'delivered_count': deliveredCount,
      'read_count': readCount,
      'replied_count': repliedCount,
      'failed_count': failedCount,
      if (deliveryLockedAt != null)
        'delivery_locked_at': deliveryLockedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }
}

class BroadcastRecipient {
  final String id;
  final String broadcastId;
  final String? contactId;
  final RecipientStatus status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? repliedAt;
  final String? errorMessage;
  final String? whatsappMessageId;
  final List<String>? templateParams;
  final DateTime createdAt;
  final Contact? contact;

  BroadcastRecipient({
    required this.id,
    required this.broadcastId,
    this.contactId,
    this.status = RecipientStatus.pending,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.repliedAt,
    this.errorMessage,
    this.whatsappMessageId,
    this.templateParams,
    required this.createdAt,
    this.contact,
  });

  factory BroadcastRecipient.fromJson(Map<String, dynamic> json) {
    return BroadcastRecipient(
      id: json['id'] as String? ?? '',
      broadcastId: json['broadcast_id'] as String? ?? '',
      contactId: json['contact_id'] as String?,
      status: RecipientStatus.fromString(json['status'] as String?),
      sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'] as String)
          : null,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : null,
      repliedAt: json['replied_at'] != null
          ? DateTime.tryParse(json['replied_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      whatsappMessageId: json['whatsapp_message_id'] as String?,
      templateParams: (json['template_params'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      contact: json['contacts'] != null
          ? Contact.fromJson(json['contacts'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'broadcast_id': broadcastId,
      if (contactId != null && contactId!.trim().isNotEmpty)
        'contact_id': contactId!.trim(),
      'status': status.toDbValue(),
      if (sentAt != null) 'sent_at': sentAt?.toIso8601String(),
      if (deliveredAt != null) 'delivered_at': deliveredAt?.toIso8601String(),
      if (readAt != null) 'read_at': readAt?.toIso8601String(),
      if (repliedAt != null) 'replied_at': repliedAt?.toIso8601String(),
      if (errorMessage != null) 'error_message': errorMessage,
      if (whatsappMessageId != null) 'whatsapp_message_id': whatsappMessageId,
      if (templateParams != null) 'template_params': templateParams,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    return map;
  }
}
