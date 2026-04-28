class FinancialAccount {
  final int? id;
  final String name;
  final String type;
  final double initialBalance;
  final double currentBalance;
  final String color;
  final String icon;
  final bool isArchived;
  final bool ignoreInTotals;
  final String createdAt;
  final String updatedAt;

  FinancialAccount({
    this.id,
    required this.name,
    this.type = 'bank',
    this.initialBalance = 0,
    this.currentBalance = 0,
    this.color = '0xFF2196F3',
    this.icon = 'account_balance',
    this.isArchived = false,
    this.ignoreInTotals = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FinancialAccount copyWith({
    int? id,
    String? name,
    String? type,
    double? initialBalance,
    double? currentBalance,
    String? color,
    String? icon,
    bool? isArchived,
    bool? ignoreInTotals,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isArchived: isArchived ?? this.isArchived,
      ignoreInTotals: ignoreInTotals ?? this.ignoreInTotals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'initialBalance': initialBalance,
        'currentBalance': currentBalance,
        'color': color,
        'icon': icon,
        'isArchived': isArchived ? 1 : 0,
        'ignoreInTotals': ignoreInTotals ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FinancialAccount.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0.0;
    }

    bool asBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value == 1;
      final normalized = '$value'.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    return FinancialAccount(
      id: map['id'],
      name: map['name'] ?? 'Conta sem nome',
      type: map['type'] ?? 'bank',
      initialBalance: asDouble(map['initialBalance']),
      currentBalance: asDouble(map['currentBalance']),
      color: map['color'] ?? '0xFF2196F3',
      icon: map['icon'] ?? 'account_balance',
      isArchived: asBool(map['isArchived']),
      ignoreInTotals: asBool(map['ignoreInTotals']),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
