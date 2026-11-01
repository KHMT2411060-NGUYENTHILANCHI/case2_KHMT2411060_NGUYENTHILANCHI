class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}