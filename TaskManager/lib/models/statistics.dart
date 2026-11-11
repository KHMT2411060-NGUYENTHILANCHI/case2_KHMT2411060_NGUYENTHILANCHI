class TaskStats {
  final int total;
  final int todo;
  final int inProgress;
  final int completed;

  TaskStats({
    this.total = 0,
    this.todo = 0,
    this.inProgress = 0,
    this.completed = 0,
  });

  factory TaskStats.fromJson(Map<String, dynamic> json) {
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    return TaskStats(
      total: n(json['total']),
      todo: n(json['todo']),
      inProgress: n(json['in_progress']),
      completed: n(json['completed']),
    );
  }
}

class AssignmentStats {
  final int assignedToMe;
  final int assignedToMeActive;
  final int primary;
  final int primaryActive;
  final int createdByMe;
  final int assignedByMe;

  AssignmentStats({
    this.assignedToMe = 0,
    this.assignedToMeActive = 0,
    this.primary = 0,
    this.primaryActive = 0,
    this.createdByMe = 0,
    this.assignedByMe = 0,
  });

  factory AssignmentStats.fromJson(Map<String, dynamic> json) {
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    return AssignmentStats(
      assignedToMe: n(json['assignedToMe']),
      assignedToMeActive: n(json['assignedToMeActive']),
      primary: n(json['primary']),
      primaryActive: n(json['primaryActive']),
      createdByMe: n(json['createdByMe']),
      assignedByMe: n(json['assignedByMe']),
    );
  }
}

/// Công việc rút gọn trong danh sách sắp đến hạn / quá hạn
class DeadlineTask {
  final String id;
  final String title;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final String? primaryAssigneeName;

  DeadlineTask({
    required this.id,
    required this.title,
    this.dueDate,
    this.priority = 'medium',
    this.status = 'todo',
    this.primaryAssigneeName,
  });

  factory DeadlineTask.fromJson(Map<String, dynamic> json) {
    final primary = json['primaryAssigneeId'];
    return DeadlineTask(
      id: (json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'].toString())?.toLocal(),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'todo').toString(),
      primaryAssigneeName:
      primary is Map ? (primary['fullName'] ?? '').toString() : null,
    );
  }
}

class DeadlineStats {
  final int days;
  final List<DeadlineTask> overdue;
  final List<DeadlineTask> upcoming;

  DeadlineStats({
    this.days = 7,
    this.overdue = const [],
    this.upcoming = const [],
  });

  factory DeadlineStats.fromJson(Map<String, dynamic> json) {
    List<DeadlineTask> parse(dynamic list) => list is List
        ? list
        .map((e) => DeadlineTask.fromJson(e as Map<String, dynamic>))
        .toList()
        : <DeadlineTask>[];

    return DeadlineStats(
      days: (json['days'] as num?)?.toInt() ?? 7,
      overdue: parse(json['overdue']),
      upcoming: parse(json['upcoming']),
    );
  }
}

/// Một dòng trong lịch sử hoạt động của công việc
class TaskActivity {
  final String id;
  final String userName;
  final String action;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  TaskActivity({
    required this.id,
    required this.userName,
    required this.action,
    this.details = const {},
    this.createdAt,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    final user = json['userId'];
    return TaskActivity(
      id: (json['_id'] ?? '').toString(),
      userName: user is Map ? (user['fullName'] ?? '').toString() : '',
      action: (json['action'] ?? '').toString(),
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : <String, dynamic>{},
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'].toString())?.toLocal(),
    );
  }
}