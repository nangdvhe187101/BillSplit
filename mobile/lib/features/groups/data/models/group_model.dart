/// Model thành viên trong nhóm, ánh xạ đúng `GroupMemberDto` từ Backend.
class GroupMemberModel {
  final String userId;
  final String fullName;
  final String phoneNumber;
  final String? avatarUrl;
  final String role; // "Owner" hoặc "Member"
  final DateTime joinedAt;

  GroupMemberModel({
    required this.userId,
    required this.fullName,
    required this.phoneNumber,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}

/// Model nhóm chia tiền, ánh xạ đúng `GroupDto` từ Backend.
class GroupModel {
  final String id;
  final String name;
  final String category;
  final String? avatarUrl;
  final String inviteCode;
  final String createdById;
  final DateTime createdAt;
  final int memberCount;
  final List<GroupMemberModel> members;

  GroupModel({
    required this.id,
    required this.name,
    required this.category,
    this.avatarUrl,
    required this.inviteCode,
    required this.createdById,
    required this.createdAt,
    required this.memberCount,
    required this.members,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      inviteCode: json['inviteCode'] as String,
      createdById: json['createdById'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      memberCount: json['memberCount'] as int,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
