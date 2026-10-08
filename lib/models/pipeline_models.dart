import 'account_models.dart';
import 'contact_models.dart';

class Pipeline {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;

  Pipeline({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  factory Pipeline.fromJson(Map<String, dynamic> json) {
    return Pipeline(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }
}

class PipelineStage {
  final String id;
  final String pipelineId;
  final String name;
  final int position;
  final String color;
  final DateTime createdAt;

  PipelineStage({
    required this.id,
    required this.pipelineId,
    required this.name,
    required this.position,
    this.color = '#3b82f6',
    required this.createdAt,
  });

  factory PipelineStage.fromJson(Map<String, dynamic> json) {
    return PipelineStage(
      id: json['id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      color: json['color'] as String? ?? '#3b82f6',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'pipeline_id': pipelineId,
      'name': name,
      'position': position,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    return map;
  }
}

enum DealStatus {
  open,
  won,
  lost;

  static DealStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'won':
        return DealStatus.won;
      case 'lost':
        return DealStatus.lost;
      case 'open':
      default:
        return DealStatus.open;
    }
  }

  String toDbValue() => name;
}

class Deal {
  final String id;
  final String userId;
  final String pipelineId;
  final String stageId;
  final String? contactId;
  final String? conversationId;
  final String? assignedTo;
  final String title;
  final double value;
  final String currency;
  final String? notes;
  final DateTime? expectedCloseDate;
  final DealStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Contact? contact;
  final PipelineStage? stage;
  final Profile? assignee;

  Deal({
    required this.id,
    required this.userId,
    required this.pipelineId,
    required this.stageId,
    this.contactId,
    this.conversationId,
    this.assignedTo,
    required this.title,
    this.value = 0.0,
    this.currency = 'USD',
    this.notes,
    this.expectedCloseDate,
    this.status = DealStatus.open,
    required this.createdAt,
    required this.updatedAt,
    this.contact,
    this.stage,
    this.assignee,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String? ?? '',
      stageId: json['stage_id'] as String? ?? '',
      contactId: json['contact_id'] as String?,
      conversationId: json['conversation_id'] as String?,
      assignedTo: json['assigned_to'] as String?,
      title: json['title'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      notes: json['notes'] as String?,
      expectedCloseDate: json['expected_close_date'] != null
          ? DateTime.tryParse(json['expected_close_date'] as String)
          : null,
      status: DealStatus.fromString(json['status'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      contact: json['contacts'] != null
          ? Contact.fromJson(json['contacts'] as Map<String, dynamic>)
          : null,
      stage: json['pipeline_stages'] != null
          ? PipelineStage.fromJson(json['pipeline_stages'] as Map<String, dynamic>)
          : null,
      assignee: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'pipeline_id': pipelineId,
      'stage_id': stageId,
      if (contactId != null && contactId!.trim().isNotEmpty)
        'contact_id': contactId!.trim(),
      if (conversationId != null && conversationId!.trim().isNotEmpty)
        'conversation_id': conversationId!.trim(),
      if (assignedTo != null && assignedTo!.trim().isNotEmpty)
        'assigned_to': assignedTo!.trim(),
      'title': title.trim(),
      'value': value,
      'currency': currency,
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      if (expectedCloseDate != null)
        'expected_close_date': expectedCloseDate?.toIso8601String(),
      'status': status.toDbValue(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }

  Deal copyWith({
    String? id,
    String? userId,
    String? pipelineId,
    String? stageId,
    String? contactId,
    String? conversationId,
    String? assignedTo,
    String? title,
    double? value,
    String? currency,
    String? notes,
    DateTime? expectedCloseDate,
    DealStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Contact? contact,
    PipelineStage? stage,
    Profile? assignee,
  }) {
    return Deal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pipelineId: pipelineId ?? this.pipelineId,
      stageId: stageId ?? this.stageId,
      contactId: contactId ?? this.contactId,
      conversationId: conversationId ?? this.conversationId,
      assignedTo: assignedTo ?? this.assignedTo,
      title: title ?? this.title,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      expectedCloseDate: expectedCloseDate ?? this.expectedCloseDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contact: contact ?? this.contact,
      stage: stage ?? this.stage,
      assignee: assignee ?? this.assignee,
    );
  }
}
