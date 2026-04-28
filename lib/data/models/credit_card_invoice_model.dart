class CreditCardInvoice {
  final int? id;
  final int cardId;
  final String referenceMonth;
  final String closingDate;
  final String dueDate;
  final double amount;
  final double paidAmount;
  final String status;
  final int? paymentAccountId;
  final String? paidDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  CreditCardInvoice({
    this.id,
    required this.cardId,
    required this.referenceMonth,
    required this.closingDate,
    required this.dueDate,
    this.amount = 0,
    this.paidAmount = 0,
    this.status = 'open',
    this.paymentAccountId,
    this.paidDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  CreditCardInvoice copyWith({
    int? id,
    int? cardId,
    String? referenceMonth,
    String? closingDate,
    String? dueDate,
    double? amount,
    double? paidAmount,
    String? status,
    int? paymentAccountId,
    bool clearPaymentAccountId = false,
    String? paidDate,
    bool clearPaidDate = false,
    String? notes,
    bool clearNotes = false,
    String? createdAt,
    String? updatedAt,
  }) {
    return CreditCardInvoice(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      referenceMonth: referenceMonth ?? this.referenceMonth,
      closingDate: closingDate ?? this.closingDate,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paymentAccountId: clearPaymentAccountId ? null : (paymentAccountId ?? this.paymentAccountId),
      paidDate: clearPaidDate ? null : (paidDate ?? this.paidDate),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cardId': cardId,
        'referenceMonth': referenceMonth,
        'closingDate': closingDate,
        'dueDate': dueDate,
        'amount': amount,
        'paidAmount': paidAmount,
        'status': status,
        'paymentAccountId': paymentAccountId,
        'paidDate': paidDate,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory CreditCardInvoice.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0.0;
    }

    return CreditCardInvoice(
      id: map['id'],
      cardId: map['cardId'] ?? 0,
      referenceMonth: map['referenceMonth'] ?? DateTime.now().toIso8601String().substring(0, 7),
      closingDate: map['closingDate'] ?? DateTime.now().toIso8601String(),
      dueDate: map['dueDate'] ?? DateTime.now().toIso8601String(),
      amount: asDouble(map['amount']),
      paidAmount: asDouble(map['paidAmount']),
      status: map['status'] ?? 'open',
      paymentAccountId: map['paymentAccountId'],
      paidDate: map['paidDate'],
      notes: map['notes'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
