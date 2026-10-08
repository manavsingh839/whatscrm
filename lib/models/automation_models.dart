import 'contact_models.dart';

class Automation {
  final String id;
  final String accountId;
  final String userId;
  final String name;
  final String? description;
  final String triggerType;
  final Map<String, dynamic> triggerConfig;
  final bool isActive;
  final int executionCount;
  final DateTime? lastExecutedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Automation({
    required this.id,
    required this.accountId,
    required this.userId,
    required this.name,
    this.description,
    required this.triggerType,
    this.triggerConfig = const {},
    this.isActive = true,
    this.executionCount = 0,
    this.lastExecutedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Automation.fromJson(Map<String, dynamic> json) {
    return Automation(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      triggerType: json['trigger_type'] as String? ?? 'new_message_received',
      triggerConfig: json['trigger_config'] as Map<String, dynamic>? ?? const {},
      isActive: json['is_active'] as bool? ?? true,
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
      'trigger_type': triggerType,
      'trigger_config': triggerConfig,
      'is_active': isActive,
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

class AutomationStep {
  final String id;
  final String automationId;
  final String? parentStepId;
  final String? branch; // 'yes' | 'no'
  final String stepType;
  final Map<String, dynamic> stepConfig;
  final int position;
  final DateTime createdAt;

  AutomationStep({
    required this.id,
    required this.automationId,
    this.parentStepId,
    this.branch,
    required this.stepType,
    this.stepConfig = const {},
    required this.position,
    required this.createdAt,
  });

  factory AutomationStep.fromJson(Map<String, dynamic> json) {
    return AutomationStep(
      id: json['id'] as String? ?? '',
      automationId: json['automation_id'] as String? ?? '',
      parentStepId: json['parent_step_id'] as String?,
      branch: json['branch'] as String?,
      stepType: json['step_type'] as String? ?? 'send_message',
      stepConfig: json['step_config'] as Map<String, dynamic>? ?? const {},
      position: (json['position'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'automation_id': automationId,
      if (parentStepId != null && parentStepId!.isNotEmpty)
        'parent_step_id': parentStepId,
      if (branch != null) 'branch': branch,
      'step_type': stepType,
      'step_config': stepConfig,
      'position': position,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    return map;
  }
}

class AutomationLog {
  final String id;
  final String automationId;
  final String userId;
  final String? contactId;
  final String triggerEvent;
  final List<dynamic> stepsExecuted;
  final String status; // 'success' | 'partial' | 'failed'
  final String? errorMessage;
  final DateTime createdAt;
  final Contact? contact;

  AutomationLog({
    required this.id,
    required this.automationId,
    required this.userId,
    this.contactId,
    required this.triggerEvent,
    this.stepsExecuted = const [],
    this.status = 'success',
    this.errorMessage,
    required this.createdAt,
    this.contact,
  });

  factory AutomationLog.fromJson(Map<String, dynamic> json) {
    return AutomationLog(
      id: json['id'] as String? ?? '',
      automationId: json['automation_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      contactId: json['contact_id'] as String?,
      triggerEvent: json['trigger_event'] as String? ?? '',
      stepsExecuted: json['steps_executed'] as List<dynamic>? ?? const [],
      status: json['status'] as String? ?? 'success',
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      contact: json['contacts'] != null
          ? Contact.fromJson(json['contacts'] as Map<String, dynamic>)
          : null,
    );
  }
}
