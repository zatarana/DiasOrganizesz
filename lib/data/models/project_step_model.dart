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
      title: map['title'],
      description: map['description'],
      orderIndex: map['orderIndex'],
      status: map['status'],
      dueDate: map['dueDate'],
      completedAt: map['completedAt'],
      reminderEnabled: map['reminderEnabled'] == 1,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}
