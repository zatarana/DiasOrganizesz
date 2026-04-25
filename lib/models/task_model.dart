class Task {
  final int? id;
  final String title;
  final String description;
  final int categoryId;
  final String priority; // 'baixa', 'media', 'alta'
  final String date;
  final String? time;
  final String status; // 'pendente', 'concluida', 'atrasada'
  final bool hasReminder;
  final String createdAt;
  final String updatedAt;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.priority,
    required this.date,
    this.time,
    required this.status,
    required this.hasReminder,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'priority': priority,
      'date': date,
      'time': time,
      'status': status,
      'hasReminder': hasReminder ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      categoryId: map['categoryId'],
      priority: map['priority'],
      date: map['date'],
      time: map['time'],
      status: map['status'],
      hasReminder: map['hasReminder'] == 1,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    int? categoryId,
    String? priority,
    String? date,
    String? time,
    String? status,
    bool? hasReminder,
    String? createdAt,
    String? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      hasReminder: hasReminder ?? this.hasReminder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
