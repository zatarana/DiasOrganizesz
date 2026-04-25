class FinancialTransaction {
  final int? id;
  final String title;
  final double amount;
  final String type; // 'receita', 'despesa'
  final String date;
  final String? dueDate;
  final int? categoryId;
  final String? paymentMethod;
  final bool isPaid;
  final bool isFixed;
  final String createdAt;

  FinancialTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.dueDate,
    this.categoryId,
    this.paymentMethod,
    required this.isPaid,
    this.isFixed = false,
    required this.createdAt,
  });

  FinancialTransaction copyWith({
    int? id,
    String? title,
    double? amount,
    String? type,
    String? date,
    String? dueDate,
    int? categoryId,
    String? paymentMethod,
    bool? isPaid,
    bool? isFixed,
    String? createdAt,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      isFixed: isFixed ?? this.isFixed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'date': date,
      'dueDate': dueDate,
      'categoryId': categoryId,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid ? 1 : 0,
      'isFixed': isFixed ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      type: map['type'],
      date: map['date'],
      dueDate: map['dueDate'],
      categoryId: map['categoryId'],
      paymentMethod: map['paymentMethod'],
      isPaid: map['isPaid'] == 1,
      isFixed: map['isFixed'] == 1,
      createdAt: map['createdAt'],
    );
  }
}
