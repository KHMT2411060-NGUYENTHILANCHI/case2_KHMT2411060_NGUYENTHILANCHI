/// Người dùng rút gọn (người tạo, người được giao, người được chia sẻ)
class UserSummary {
  final String id;
  final String fullName;
  final String email;

  UserSummary({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }

  // Backend có thể trả object (đã populate) hoặc chỉ là id dạng chuỗi
  static UserSummary? fromAny(dynamic value) {
    if (value is Map<String, dynamic>) return UserSummary.fromJson(value);
    return null;
  }
}

/// Một bản ghi chia sẻ công việc
class TaskShare {
  final String id;
  final UserSummary? user;
  final String permission; // viewer | editor
  final UserSummary? sharedBy;

  TaskShare({
    required this.id,
    this.user,
    this.permission = 'viewer',
    this.sharedBy,
  });

  factory TaskShare.fromJson(Map<String, dynamic> json) {
    return TaskShare(
      id: (json['_id'] ?? '').toString(),
      user: UserSummary.fromAny(json['userId']),
      permission: (json['permission'] ?? 'viewer').toString(),
      sharedBy: UserSummary.fromAny(json['sharedBy']),
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final UserSummary? createdBy;
  final List<UserSummary> assignees;
  final UserSummary? primaryAssignee;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String priority; // low | medium | high
  final String status; // todo | in_progress | completed
  final DateTime? createdAt;

  // Vai trò và quyền của người đang đăng nhập (do backend trả về)
  final String? myRole; // owner | editor | assignee | viewer
  final bool canEdit;
  final bool canChangeStatus;
  final bool canDelete;
  final bool canManage;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.createdBy,
    this.assignees = const [],
    this.primaryAssignee,
    this.startDate,
    this.dueDate,
    this.priority = 'medium',
    this.status = 'todo',
    this.createdAt,
    this.myRole,
    this.canEdit = false,
    this.canChangeStatus = false,
    this.canDelete = false,
    this.canManage = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

    final rawAssignees = json['assigneeIds'];
    final perms = json['permissions'] is Map<String, dynamic>
        ? json['permissions'] as Map<String, dynamic>
        : <String, dynamic>{};

    return Task(
      id: (json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdBy: UserSummary.fromAny(json['createdBy']),
      assignees: rawAssignees is List
          ? rawAssignees
          .map(UserSummary.fromAny)
          .whereType<UserSummary>()
          .toList()
          : [],
      primaryAssignee: UserSummary.fromAny(json['primaryAssigneeId']),
      startDate: parseDate(json['startDate']),
      dueDate: parseDate(json['dueDate']),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'todo').toString(),
      createdAt: parseDate(json['createdAt']),
      myRole: json['myRole']?.toString(),
      canEdit: perms['canEdit'] == true,
      canChangeStatus: perms['canChangeStatus'] == true,
      canDelete: perms['canDelete'] == true,
      canManage: perms['canManage'] == true,
    );
  }

  bool get isCompleted => status == 'completed';

  bool get isOverdue =>
      dueDate != null && !isCompleted && dueDate!.isBefore(DateTime.now());
}