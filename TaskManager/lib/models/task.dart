/// Người dùng rút gọn (người tạo, người được giao)
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
      id: (json['_id'] ?? '').toString(),
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
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

    final rawAssignees = json['assigneeIds'];

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
    );
  }

  bool get isCompleted => status == 'completed';

  bool get isOverdue =>
      dueDate != null && !isCompleted && dueDate!.isBefore(DateTime.now());
}