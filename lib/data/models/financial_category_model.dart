class FinancialCategory {
  final int? id;
  final String name;
  final String type; // 'income', 'expense', 'both'
  final String color;
  final String icon;
  final String createdAt;
  final String updatedAt;

  FinancialCategory({
    this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  FinancialCategory copyWith({
    int? id,
    String? name,
    String? type,
    String? color,
    String? icon,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory FinancialCategory.fromMap(Map<String, dynamic> map) {
    return FinancialCategory(
      id: map['id'],
      name: map['name'],
      type: map['type'] ?? 'both',
      color: map['color'],
      icon: map['icon'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
