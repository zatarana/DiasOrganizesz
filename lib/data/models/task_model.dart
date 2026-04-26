class Task {
  final int? id;
  final String title;
  final String? description;
  final int? categoryId;
  final int? projectId;
  final String priority; // 'baixa', 'media', 'alta'
  final String? date;
  final String? time;
  final String status; // 'pendente', 'concluida', 'atrasada'
  final bool reminderEnabled;
  final String createdAt;
  final String updatedAt;

  Task({
    this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.projectId,
    required this.priority,
    this.date,
    this.time,
    required this.status,
    required this.reminderEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'projectId': projectId,
      'priority': priority,
      'date': date,
      'time': time,
      'status': status,
      'reminderEnabled': reminderEnabled ? 1 : 0,
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
      projectId: map['projectId'],
      priority: map['priority'],
      date: map['date'],
      time: map['time'],
      status: map['status'],
      reminderEnabled: map['reminderEnabled'] == 1,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    int? categoryId,
    int? projectId,
    String? priority,
    String? date,
    String? time,
    String? status,
    bool? reminderEnabled,
    String? createdAt,
    String? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      projectId: projectId ?? this.projectId,
      priority: priority ?? this.priority,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
