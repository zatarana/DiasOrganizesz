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
  final int? subcategoryId;
  final int? accountId;
  final String? paymentMethod;
  final String status; // 'pending', 'paid', 'overdue', 'canceled'
  final bool reminderEnabled;
  final bool isFixed;
  final String recurrenceType; // 'none', 'monthly'
  final String? notes;
  final String? tags;
  final bool ignoreInTotals;
  final bool ignoreInReports;
  final bool ignoreInMonthlySavings;
  final int? debtId;
  final int? creditCardId;
  final int? creditCardInvoiceId;
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
    this.subcategoryId,
    this.accountId,
    this.paymentMethod,
    required this.status,
    this.reminderEnabled = false,
    this.isFixed = false,
    this.recurrenceType = 'none',
    this.notes,
    this.tags,
    this.ignoreInTotals = false,
    this.ignoreInReports = false,
    this.ignoreInMonthlySavings = false,
    this.debtId,
    this.creditCardId,
    this.creditCardInvoiceId,
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
    bool clearDueDate = false,
    String? paidDate,
    bool clearPaidDate = false,
    int? categoryId,
    bool clearCategoryId = false,
    int? subcategoryId,
    bool clearSubcategoryId = false,
    int? accountId,
    bool clearAccountId = false,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    String? status,
    bool? reminderEnabled,
    bool? isFixed,
    String? recurrenceType,
    String? notes,
    bool clearNotes = false,
    String? tags,
    bool clearTags = false,
    bool? ignoreInTotals,
    bool? ignoreInReports,
    bool? ignoreInMonthlySavings,
    int? debtId,
    bool clearDebtId = false,
    int? creditCardId,
    bool clearCreditCardId = false,
    int? creditCardInvoiceId,
    bool clearCreditCardInvoiceId = false,
    int? installmentNumber,
    bool clearInstallmentNumber = false,
    int? totalInstallments,
    bool clearTotalInstallments = false,
    double? discountAmount,
    bool clearDiscountAmount = false,
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
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategoryId ? null : (subcategoryId ?? this.subcategoryId),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      paymentMethod: clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isFixed: isFixed ?? this.isFixed,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      notes: clearNotes ? null : (notes ?? this.notes),
      tags: clearTags ? null : (tags ?? this.tags),
      ignoreInTotals: ignoreInTotals ?? this.ignoreInTotals,
      ignoreInReports: ignoreInReports ?? this.ignoreInReports,
      ignoreInMonthlySavings: ignoreInMonthlySavings ?? this.ignoreInMonthlySavings,
      debtId: clearDebtId ? null : (debtId ?? this.debtId),
      creditCardId: clearCreditCardId ? null : (creditCardId ?? this.creditCardId),
      creditCardInvoiceId: clearCreditCardInvoiceId ? null : (creditCardInvoiceId ?? this.creditCardInvoiceId),
      installmentNumber: clearInstallmentNumber ? null : (installmentNumber ?? this.installmentNumber),
      totalInstallments: clearTotalInstallments ? null : (totalInstallments ?? this.totalInstallments),
      discountAmount: clearDiscountAmount ? null : (discountAmount ?? this.discountAmount),
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
      'subcategoryId': subcategoryId,
      'accountId': accountId,
      'paymentMethod': paymentMethod,
      'status': status,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'isFixed': isFixed ? 1 : 0,
      'recurrenceType': recurrenceType,
      'notes': notes,
      'tags': tags,
      'ignoreInTotals': ignoreInTotals ? 1 : 0,
      'ignoreInReports': ignoreInReports ? 1 : 0,
      'ignoreInMonthlySavings': ignoreInMonthlySavings ? 1 : 0,
      'debtId': debtId,
      'creditCardId': creditCardId,
      'creditCardInvoiceId': creditCardInvoiceId,
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

    bool asBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value == 1;
      final normalized = '$value'.toLowerCase();
      return normalized == 'true' || normalized == '1';
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
      subcategoryId: map['subcategoryId'],
      accountId: map['accountId'],
      paymentMethod: map['paymentMethod'],
      status: mappedStatus,
      reminderEnabled: asBool(map['reminderEnabled']),
      isFixed: asBool(map['isFixed']),
      recurrenceType: map['recurrenceType'] ?? 'none',
      notes: map['notes'],
      tags: map['tags'],
      ignoreInTotals: asBool(map['ignoreInTotals']),
      ignoreInReports: asBool(map['ignoreInReports']),
      ignoreInMonthlySavings: asBool(map['ignoreInMonthlySavings']),
      debtId: map['debtId'],
      creditCardId: map['creditCardId'],
      creditCardInvoiceId: map['creditCardInvoiceId'],
      installmentNumber: map['installmentNumber'],
      totalInstallments: map['totalInstallments'],
      discountAmount: map['discountAmount'] == null ? null : asDouble(map['discountAmount']),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
