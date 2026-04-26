class TaskCategory {
  final int? id;
  final String name;
  final String color;
  final String? icon;
  final String createdAt;

  TaskCategory({
    this.id,
    required this.name,
    required this.color,
    this.icon,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'createdAt': createdAt,
    };
  }

  factory TaskCategory.fromMap(Map<String, dynamic> map) {
    return TaskCategory(
      id: map['id'],
      name: map['name'],
      color: map['color'] ?? '0xFF2196F3',
      icon: map['icon'],
      createdAt: map['createdAt'],
    );
  }
}
