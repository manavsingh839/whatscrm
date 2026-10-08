class Tag {
  final String id;
  final String userId;
  final String name;
  final String color;
  final DateTime createdAt;

  Tag({
    required this.id,
    required this.userId,
    required this.name,
    this.color = '#3b82f6',
    required this.createdAt,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#3b82f6',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }
}

class Contact {
  final String id;
  final String userId;
  final String accountId;
  final String phone;
  final String? phoneNormalized;
  final String? waUserId;
  final String? waParentUserId;
  final String? waUsername;
  final String? name;
  final String? email;
  final String? company;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Tag> tags;

  Contact({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.phone,
    this.phoneNormalized,
    this.waUserId,
    this.waParentUserId,
    this.waUsername,
    this.name,
    this.email,
    this.company,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  String get displayName =>
      (name != null && name!.trim().isNotEmpty)
          ? name!
          : (waUsername != null && waUsername!.trim().isNotEmpty)
              ? '@$waUsername'
              : phone;

  factory Contact.fromJson(Map<String, dynamic> json) {
    List<Tag> parsedTags = [];
    if (json['contact_tags'] is List) {
      for (final item in json['contact_tags'] as List) {
        if (item is Map<String, dynamic> && item['tags'] is Map<String, dynamic>) {
          parsedTags.add(Tag.fromJson(item['tags'] as Map<String, dynamic>));
        }
      }
    } else if (json['tags'] is List) {
      for (final item in json['tags'] as List) {
        if (item is Map<String, dynamic>) {
          parsedTags.add(Tag.fromJson(item));
        }
      }
    }

    return Contact(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      phoneNormalized: json['phone_normalized'] as String?,
      waUserId: json['wa_user_id'] as String?,
      waParentUserId: json['wa_parent_user_id'] as String?,
      waUsername: json['wa_username'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      company: json['company'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      tags: parsedTags,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'phone': phone,
      if (phoneNormalized != null && phoneNormalized!.isNotEmpty)
        'phone_normalized': phoneNormalized,
      if (waUserId != null && waUserId!.isNotEmpty) 'wa_user_id': waUserId,
      if (waParentUserId != null && waParentUserId!.isNotEmpty)
        'wa_parent_user_id': waParentUserId,
      if (waUsername != null && waUsername!.isNotEmpty) 'wa_username': waUsername,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (company != null) 'company': company,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    if (accountId.trim().isNotEmpty) map['account_id'] = accountId.trim();
    return map;
  }

  Contact copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? phone,
    String? phoneNormalized,
    String? waUserId,
    String? waParentUserId,
    String? waUsername,
    String? name,
    String? email,
    String? company,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Tag>? tags,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      phone: phone ?? this.phone,
      phoneNormalized: phoneNormalized ?? this.phoneNormalized,
      waUserId: waUserId ?? this.waUserId,
      waParentUserId: waParentUserId ?? this.waParentUserId,
      waUsername: waUsername ?? this.waUsername,
      name: name ?? this.name,
      email: email ?? this.email,
      company: company ?? this.company,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}

class CustomField {
  final String id;
  final String userId;
  final String accountId;
  final String fieldName;
  final String fieldType; // 'text', 'number', 'date', 'select', 'boolean'
  final Map<String, dynamic>? fieldOptions;
  final DateTime createdAt;

  CustomField({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.fieldName,
    required this.fieldType,
    this.fieldOptions,
    required this.createdAt,
  });

  factory CustomField.fromJson(Map<String, dynamic> json) {
    return CustomField(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      fieldName: json['field_name'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? 'text',
      fieldOptions: json['field_options'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'field_name': fieldName,
      'field_type': fieldType,
      if (fieldOptions != null) 'field_options': fieldOptions,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    if (accountId.trim().isNotEmpty) map['account_id'] = accountId.trim();
    return map;
  }
}

class ContactCustomValue {
  final String id;
  final String contactId;
  final String customFieldId;
  final String? value;

  ContactCustomValue({
    required this.id,
    required this.contactId,
    required this.customFieldId,
    this.value,
  });

  factory ContactCustomValue.fromJson(Map<String, dynamic> json) {
    return ContactCustomValue(
      id: json['id'] as String? ?? '',
      contactId: json['contact_id'] as String? ?? '',
      customFieldId: json['custom_field_id'] as String? ?? '',
      value: json['value'] as String?,
    );
  }
}

class ContactNote {
  final String id;
  final String contactId;
  final String userId;
  final String noteText;
  final DateTime createdAt;

  ContactNote({
    required this.id,
    required this.contactId,
    required this.userId,
    required this.noteText,
    required this.createdAt,
  });

  factory ContactNote.fromJson(Map<String, dynamic> json) {
    return ContactNote(
      id: json['id'] as String? ?? '',
      contactId: json['contact_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      noteText: json['note_text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'contact_id': contactId,
      'note_text': noteText,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.trim().isNotEmpty) map['id'] = id.trim();
    if (userId.trim().isNotEmpty) map['user_id'] = userId.trim();
    return map;
  }
}
