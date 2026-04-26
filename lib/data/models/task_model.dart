class Task {
  final int? id;
  final String title;
  final String? description;
  final int? categoryId;
  final int? projectId;
  final int? projectStepId;
  final int? parentTaskId;
  final String priority; // 'baixa', 'media', 'alta'
  final String? date;
  final String? time;
  final String status; // 'pendente', 'concluida', 'atrasada', 'canceled'
  final bool reminderEnabled;
  final String recurrenceType; // 'none', 'daily', 'weekly', 'monthly'
  final String createdAt;
  final String updatedAt;

  Task({
    this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.projectId,
    this.projectStepId,
    this.parentTaskId,
    required this.priority,
    this.date,
    this.time,
    required this.status,
    required this.reminderEnabled,
    this.recurrenceType = 'none',
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
      'projectStepId': projectStepId,
      'parentTaskId': parentTaskId,
      'priority': priority,
      'date': date,
      'time': time,
      'status': status,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'recurrenceType': recurrenceType,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'] ?? 'Tarefa sem título',
      description: map['description'],
      categoryId: map['categoryId'],
      projectId: map['projectId'],
      projectStepId: map['projectStepId'],
      parentTaskId: map['parentTaskId'],
      priority: map['priority'] ?? 'media',
      date: map['date'],
      time: map['time'],
      status: map['status'] ?? 'pendente',
      reminderEnabled: map['reminderEnabled'] == 1,
      recurrenceType: map['recurrenceType'] ?? 'none',
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }

  Task copyWith({
    int? id,
    bool clearId = false,
    String? title,
    String? description,
    bool clearDescription = false,
    int? categoryId,
    bool clearCategoryId = false,
    int? projectId,
    bool clearProjectId = false,
    int? projectStepId,
    bool clearProjectStepId = false,
    int? parentTaskId,
    bool clearParentTaskId = false,
    String? priority,
    String? date,
    bool clearDate = false,
    String? time,
    bool clearTime = false,
    String? status,
    bool? reminderEnabled,
    String? recurrenceType,
    String? createdAt,
    String? updatedAt,
  }) {
    return Task(
      id: clearId ? null : (id ?? this.id),
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      projectStepId: clearProjectStepId ? null : (projectStepId ?? this.projectStepId),
      parentTaskId: clearParentTaskId ? null : (parentTaskId ?? this.parentTaskId),
      priority: priority ?? this.priority,
      date: clearDate ? null : (date ?? this.date),
      time: clearTime ? null : (time ?? this.time),
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
