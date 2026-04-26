class ProjectStep {
  final int? id;
  final int projectId;
  final String title;
  final String? description;
  final int orderIndex;
  final String status; // pending, in_progress, completed, canceled
  final String? dueDate;
  final String? completedAt;
  final bool reminderEnabled;
  final String createdAt;
  final String updatedAt;

  ProjectStep({
    this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.orderIndex,
    required this.status,
    this.dueDate,
    this.completedAt,
    this.reminderEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  ProjectStep copyWith({
    int? id,
    int? projectId,
    String? title,
    String? description,
    bool clearDescription = false,
    int? orderIndex,
    String? status,
    String? dueDate,
    bool clearDueDate = false,
    String? completedAt,
    bool clearCompletedAt = false,
    bool? reminderEnabled,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProjectStep(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'description': description,
      'orderIndex': orderIndex,
      'status': status,
      'dueDate': dueDate,
      'completedAt': completedAt,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ProjectStep.fromMap(Map<String, dynamic> map) {
    return ProjectStep(
      id: map['id'],
      projectId: map['projectId'],
      title: map['title'] ?? 'Sessão sem título',
      description: map['description'],
      orderIndex: map['orderIndex'] ?? 0,
      status: map['status'] ?? 'pending',
      dueDate: map['dueDate'],
      completedAt: map['completedAt'],
      reminderEnabled: map['reminderEnabled'] == 1,
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
