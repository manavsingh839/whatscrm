class NotificationModel {
  final String id;
  final String accountId;
  final String userId;
  final String type; // 'conversation_assigned'
  final String? conversationId;
  final String? contactId;
  final String? actorUserId;
  final String title;
  final String? body;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.accountId,
    required this.userId,
    this.type = 'conversation_assigned',
    this.conversationId,
    this.contactId,
    this.actorUserId,
    required this.title,
    this.body,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'conversation_assigned',
      conversationId: json['conversation_id'] as String?,
      contactId: json['contact_id'] as String?,
      actorUserId: json['actor_user_id'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'user_id': userId,
      'type': type,
      'conversation_id': conversationId,
      'contact_id': contactId,
      'actor_user_id': actorUserId,
      'title': title,
      'body': body,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
