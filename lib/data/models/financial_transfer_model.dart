class FinancialTransfer {
  final int? id;
  final int fromAccountId;
  final int toAccountId;
  final double amount;
  final String transferDate;
  final String? description;
  final String? notes;
  final bool ignoreInReports;
  final String createdAt;
  final String updatedAt;

  FinancialTransfer({
    this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.transferDate,
    this.description,
    this.notes,
    this.ignoreInReports = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FinancialTransfer copyWith({
    int? id,
    int? fromAccountId,
    int? toAccountId,
    double? amount,
    String? transferDate,
    String? description,
    bool clearDescription = false,
    String? notes,
    bool clearNotes = false,
    bool? ignoreInReports,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialTransfer(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      transferDate: transferDate ?? this.transferDate,
      description: clearDescription ? null : (description ?? this.description),
      notes: clearNotes ? null : (notes ?? this.notes),
      ignoreInReports: ignoreInReports ?? this.ignoreInReports,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amount': amount,
        'transferDate': transferDate,
        'description': description,
        'notes': notes,
        'ignoreInReports': ignoreInReports ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FinancialTransfer.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0.0;
    }

    return FinancialTransfer(
      id: map['id'],
      fromAccountId: map['fromAccountId'] ?? 0,
      toAccountId: map['toAccountId'] ?? 0,
      amount: asDouble(map['amount']),
      transferDate: map['transferDate'] ?? DateTime.now().toIso8601String(),
      description: map['description'],
      notes: map['notes'],
      ignoreInReports: map['ignoreInReports'] == 1,
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
