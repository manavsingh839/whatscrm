class FlowRow {
  final String id;
  final String accountId;
  final String userId;
  final String name;
  final String? description;
  final String status; // 'draft' | 'active' | 'archived'
  final String triggerType; // 'keyword' | 'first_inbound_message' | 'manual'
  final Map<String, dynamic> triggerConfig;
  final String? entryNodeId;
  final String fallbackPolicy;
  final int executionCount;
  final DateTime? lastExecutedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  FlowRow({
    required this.id,
    required this.accountId,
    required this.userId,
    required this.name,
    this.description,
    this.status = 'draft',
    this.triggerType = 'keyword',
    this.triggerConfig = const {},
    this.entryNodeId,
    this.fallbackPolicy = 'stop',
    this.executionCount = 0,
    this.lastExecutedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  factory FlowRow.fromJson(Map<String, dynamic> json) {
    return FlowRow(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'draft',
      triggerType: json['trigger_type'] as String? ?? 'keyword',
      triggerConfig: json['trigger_config'] as Map<String, dynamic>? ?? const {},
      entryNodeId: json['entry_node_id'] as String?,
      fallbackPolicy: json['fallback_policy'] as String? ?? 'stop',
      executionCount: (json['execution_count'] as num?)?.toInt() ?? 0,
      lastExecutedAt: json['last_executed_at'] != null
          ? DateTime.tryParse(json['last_executed_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'status': status,
      'trigger_type': triggerType,
      'trigger_config': triggerConfig,
      if (entryNodeId != null && entryNodeId!.isNotEmpty)
        'entry_node_id': entryNodeId,
      'fallback_policy': fallbackPolicy,
      'execution_count': executionCount,
      if (lastExecutedAt != null)
        'last_executed_at': lastExecutedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (accountId.trim().isNotEmpty) map['account_id'] = accountId.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }
}

class FlowNodeRow {
  final String id;
  final String flowId;
  final String nodeKey;
  final String nodeType; // 'start', 'send_message', 'send_buttons', 'send_list', 'send_media', 'collect_input', 'condition', 'set_tag', 'handoff', 'end'
  final double positionX;
  final double positionY;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime updatedAt;

  FlowNodeRow({
    required this.id,
    required this.flowId,
    required this.nodeKey,
    required this.nodeType,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.config = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory FlowNodeRow.fromJson(Map<String, dynamic> json) {
    return FlowNodeRow(
      id: json['id'] as String? ?? '',
      flowId: json['flow_id'] as String? ?? '',
      nodeKey: json['node_key'] as String? ?? '',
      nodeType: json['node_type'] as String? ?? 'send_message',
      positionX: (json['position_x'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['position_y'] as num?)?.toDouble() ?? 0.0,
      config: json['config'] as Map<String, dynamic>? ?? const {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'flow_id': flowId,
      'node_key': nodeKey,
      'node_type': nodeType,
      'position_x': positionX,
      'position_y': positionY,
      'config': config,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    return map;
  }

  FlowNodeRow copyWith({
    String? id,
    String? flowId,
    String? nodeKey,
    String? nodeType,
    double? positionX,
    double? positionY,
    Map<String, dynamic>? config,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FlowNodeRow(
      id: id ?? this.id,
      flowId: flowId ?? this.flowId,
      nodeKey: nodeKey ?? this.nodeKey,
      nodeType: nodeType ?? this.nodeType,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FlowRunRow {
  final String id;
  final String flowId;
  final String accountId;
  final String? contactId;
  final String? conversationId;
  final String status; // 'running' | 'completed' | 'failed' | 'handed_off'
  final String? currentNodeKey;
  final Map<String, dynamic> vars;
  final DateTime createdAt;
  final DateTime updatedAt;

  FlowRunRow({
    required this.id,
    required this.flowId,
    required this.accountId,
    this.contactId,
    this.conversationId,
    required this.status,
    this.currentNodeKey,
    this.vars = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory FlowRunRow.fromJson(Map<String, dynamic> json) {
    return FlowRunRow(
      id: json['id'] as String? ?? '',
      flowId: json['flow_id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      contactId: json['contact_id'] as String?,
      conversationId: json['conversation_id'] as String?,
      status: json['status'] as String? ?? 'running',
      currentNodeKey: json['current_node_key'] as String?,
      vars: json['vars'] as Map<String, dynamic>? ?? const {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
