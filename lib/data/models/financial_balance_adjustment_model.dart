class FinancialBalanceAdjustment {
  final int? id;
  final int accountId;
  final double previousBalance;
  final double newBalance;
  final double delta;
  final String adjustmentDate;
  final String? reason;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  FinancialBalanceAdjustment({
    this.id,
    required this.accountId,
    required this.previousBalance,
    required this.newBalance,
    required this.delta,
    required this.adjustmentDate,
    this.reason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  FinancialBalanceAdjustment copyWith({
    int? id,
    int? accountId,
    double? previousBalance,
    double? newBalance,
    double? delta,
    String? adjustmentDate,
    String? reason,
    bool clearReason = false,
    String? notes,
    bool clearNotes = false,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialBalanceAdjustment(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      previousBalance: previousBalance ?? this.previousBalance,
      newBalance: newBalance ?? this.newBalance,
      delta: delta ?? this.delta,
      adjustmentDate: adjustmentDate ?? this.adjustmentDate,
      reason: clearReason ? null : (reason ?? this.reason),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'accountId': accountId,
        'previousBalance': previousBalance,
        'newBalance': newBalance,
        'delta': delta,
        'adjustmentDate': adjustmentDate,
        'reason': reason,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FinancialBalanceAdjustment.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0.0;
    }

    return FinancialBalanceAdjustment(
      id: map['id'],
      accountId: map['accountId'] ?? 0,
      previousBalance: asDouble(map['previousBalance']),
      newBalance: asDouble(map['newBalance']),
      delta: asDouble(map['delta']),
      adjustmentDate: map['adjustmentDate'] ?? DateTime.now().toIso8601String(),
      reason: map['reason'],
      notes: map['notes'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
