class FinancialTransaction {
  final int? id;
  final String title;
  final String? description;
  final double amount;
  final String type; // 'income', 'expense'
  final String transactionDate;
  final String? dueDate;
  final String? paidDate;
  final int? categoryId;
  final String? paymentMethod;
  final String status; // 'pending', 'paid', 'overdue', 'canceled'
  final bool reminderEnabled;
  final bool isFixed;
  final String recurrenceType; // 'none', 'monthly'
  final String? notes;
  final int? debtId;
  final int? installmentNumber;
  final int? totalInstallments;
  final double? discountAmount;
  final String createdAt;
  final String updatedAt;

  FinancialTransaction({
    this.id,
    required this.title,
    this.description,
    required this.amount,
    required this.type,
    required this.transactionDate,
    this.dueDate,
    this.paidDate,
    this.categoryId,
    this.paymentMethod,
    required this.status,
    this.reminderEnabled = false,
    this.isFixed = false,
    this.recurrenceType = 'none',
    this.notes,
    this.debtId,
    this.installmentNumber,
    this.totalInstallments,
    this.discountAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  FinancialTransaction copyWith({
    int? id,
    String? title,
    String? description,
    double? amount,
    String? type,
    String? transactionDate,
    String? dueDate,
    String? paidDate,
    int? categoryId,
    String? paymentMethod,
    String? status,
    bool? reminderEnabled,
    bool? isFixed,
    String? recurrenceType,
    String? notes,
    int? debtId,
    int? installmentNumber,
    int? totalInstallments,
    double? discountAmount,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      transactionDate: transactionDate ?? this.transactionDate,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isFixed: isFixed ?? this.isFixed,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      notes: notes ?? this.notes,
      debtId: debtId ?? this.debtId,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      discountAmount: discountAmount ?? this.discountAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'type': type,
      'transactionDate': transactionDate,
      'dueDate': dueDate,
      'paidDate': paidDate,
      'categoryId': categoryId,
      'paymentMethod': paymentMethod,
      'status': status,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'isFixed': isFixed ? 1 : 0,
      'recurrenceType': recurrenceType,
      'notes': notes,
      'debtId': debtId,
      'installmentNumber': installmentNumber,
      'totalInstallments': totalInstallments,
      'discountAmount': discountAmount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    String mappedType = map['type'] ?? 'expense';
    if (mappedType == 'receita') mappedType = 'income';
    if (mappedType == 'despesa') mappedType = 'expense';

    String mappedStatus = map['status'] ?? 'pending';
    if (map['status'] == null && map['isPaid'] != null) {
      mappedStatus = (map['isPaid'] == 1) ? 'paid' : 'pending';
    }

    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0.0;
    }

    return FinancialTransaction(
      id: map['id'],
      title: map['title'] ?? 'Movimentação sem título',
      description: map['description'],
      amount: asDouble(map['amount']),
      type: mappedType,
      transactionDate: map['transactionDate'] ?? map['date'] ?? DateTime.now().toIso8601String(),
      dueDate: map['dueDate'],
      paidDate: map['paidDate'],
      categoryId: map['categoryId'],
      paymentMethod: map['paymentMethod'],
      status: mappedStatus,
      reminderEnabled: map['reminderEnabled'] == 1,
      isFixed: map['isFixed'] == 1,
      recurrenceType: map['recurrenceType'] ?? 'none',
      notes: map['notes'],
      debtId: map['debtId'],
      installmentNumber: map['installmentNumber'],
      totalInstallments: map['totalInstallments'],
      discountAmount: map['discountAmount'] == null ? null : asDouble(map['discountAmount']),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
