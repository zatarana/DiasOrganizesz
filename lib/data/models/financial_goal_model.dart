class FinancialGoal {
  final int? id;
  final String name;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final String? targetDate;
  final String status;
  final String color;
  final String icon;
  final String createdAt;
  final String updatedAt;

  FinancialGoal({
    this.id,
    required this.name,
    this.description,
    required this.targetAmount,
    this.currentAmount = 0,
    this.targetDate,
    this.status = 'active',
    this.color = '0xFF4CAF50',
    this.icon = 'flag',
    required this.createdAt,
    required this.updatedAt,
  });

  FinancialGoal copyWith({
    int? id,
    String? name,
    String? description,
    bool clearDescription = false,
    double? targetAmount,
    double? currentAmount,
    String? targetDate,
    bool clearTargetDate = false,
    String? status,
    String? color,
    String? icon,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      status: status ?? this.status,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate,
        'status': status,
        'color': color,
        'icon': icon,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FinancialGoal.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0.0;
    }

    return FinancialGoal(
      id: map['id'],
      name: map['name'] ?? 'Meta sem nome',
      description: map['description'],
      targetAmount: asDouble(map['targetAmount']),
      currentAmount: asDouble(map['currentAmount']),
      targetDate: map['targetDate'],
      status: map['status'] ?? 'active',
      color: map['color'] ?? '0xFF4CAF50',
      icon: map['icon'] ?? 'flag',
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
