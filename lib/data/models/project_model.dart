class Project {
  final int? id;
  final String name;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String status; // active, completed, paused, canceled
  final String? notes;
  final String? completedAt;
  final double progress; // 0..100
  final bool reminderEnabled;
  final String priority; // baixa, media, alta
  final String color; // hex string
  final String icon; // icon key
    this.notes,
    this.completedAt,
    this.progress = 0,
    this.reminderEnabled = false,
    this.priority = 'media',
    this.color = '0xFF2196F3',
    this.icon = 'rocket_launch',
      'notes': notes,
      'completedAt': completedAt,
      'progress': progress,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'priority': priority,
      'color': color,
      'icon': icon,
      notes: map['notes'],
      completedAt: map['completedAt'],
      progress: (map['progress'] is num) ? (map['progress'] as num).toDouble() : 0,
      reminderEnabled: map['reminderEnabled'] == 1,
      priority: map['priority'] ?? 'media',
      color: map['color'] ?? '0xFF2196F3',
      icon: map['icon'] ?? 'rocket_launch',
    String? notes,
    String? completedAt,
    bool clearCompletedAt = false,
    double? progress,
    bool? reminderEnabled,
    String? priority,
    String? color,
    String? icon,
      notes: notes ?? this.notes,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      progress: progress ?? this.progress,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      priority: priority ?? this.priority,
      color: color ?? this.color,
      icon: icon ?? this.icon,
  final String? notes;
  final String? completedAt;
  final double progress; // 0..100
  final bool reminderEnabled;
  final String priority; // baixa, media, alta
  final String color; // hex string
  final String icon; // icon key
  final String createdAt;
  final String updatedAt;

  Project({
    this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    required this.status,
    this.notes,
    this.completedAt,
    this.progress = 0,
    this.reminderEnabled = false,
    this.priority = 'media',
    this.color = '0xFF2196F3',
    this.icon = 'rocket_launch',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'notes': notes,
      'completedAt': completedAt,
      'progress': progress,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'priority': priority,
      'color': color,
      'icon': icon,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      startDate: map['startDate'],
      endDate: map['endDate'],
      status: map['status'],
      notes: map['notes'],
      completedAt: map['completedAt'],
      progress: (map['progress'] is num) ? (map['progress'] as num).toDouble() : 0,
      reminderEnabled: map['reminderEnabled'] == 1,
      priority: map['priority'] ?? 'media',
      color: map['color'] ?? '0xFF2196F3',
      icon: map['icon'] ?? 'rocket_launch',
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Project copyWith({
    int? id,
    String? name,
    String? description,
    String? startDate,
    String? endDate,
    String? status,
    String? notes,
    String? completedAt,
    bool clearCompletedAt = false,
    double? progress,
    bool? reminderEnabled,
    String? priority,
    String? color,
    String? icon,
    String? createdAt,
    String? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      progress: progress ?? this.progress,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      priority: priority ?? this.priority,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
