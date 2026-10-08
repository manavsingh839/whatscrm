enum AccountRole {
  owner,
  admin,
  agent,
  viewer;

  static AccountRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return AccountRole.owner;
      case 'admin':
        return AccountRole.admin;
      case 'agent':
        return AccountRole.agent;
      case 'viewer':
      default:
        return AccountRole.viewer;
    }
  }

  String toDbValue() => name;

  bool get isOwner => this == AccountRole.owner;
  bool get isAdminOrAbove => this == AccountRole.owner || this == AccountRole.admin;
  bool get canWrite => this != AccountRole.viewer;
}

class Profile {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String role;
  final List<String> betaFeatures;
  final String? accountId;
  final AccountRole accountRole;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.role,
    this.betaFeatures = const [],
    this.accountId,
    this.accountRole = AccountRole.agent,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      betaFeatures: (json['beta_features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      accountId: json['account_id'] as String?,
      accountRole: AccountRole.fromString(json['account_role'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role,
      'beta_features': betaFeatures,
      'account_id': accountId,
      'account_role': accountRole.toDbValue(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Account {
  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      ownerUserId: json['owner_user_id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_user_id': ownerUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class AccountMember {
  final String userId;
  final String fullName;
  final String? email;
  final String? avatarUrl;
  final AccountRole role;
  final DateTime joinedAt;

  AccountMember({
    required this.userId,
    required this.fullName,
    this.email,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  factory AccountMember.fromJson(Map<String, dynamic> json) {
    return AccountMember(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: AccountRole.fromString(json['role'] as String?),
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AccountInvitation {
  final String id;
  final String accountId;
  final AccountRole role;
  final String? createdByUserId;
  final String? label;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedByUserId;

  AccountInvitation({
    required this.id,
    required this.accountId,
    required this.role,
    this.createdByUserId,
    this.label,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
    this.acceptedByUserId,
  });

  factory AccountInvitation.fromJson(Map<String, dynamic> json) {
    return AccountInvitation(
      id: json['id'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      role: AccountRole.fromString(json['role'] as String?),
      createdByUserId: json['created_by_user_id'] as String?,
      label: json['label'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ?? DateTime.now(),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'] as String)
          : null,
      acceptedByUserId: json['accepted_by_user_id'] as String?,
    );
  }
}
