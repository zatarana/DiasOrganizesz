class FinancialTransaction {
  final int? id;
  final String title;
  final double amount;
  final String type; // 'receita', 'despesa'
  final String date;
  final int? categoryId;
  final bool isPaid;
  final String createdAt;

  FinancialTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.categoryId,
    required this.isPaid,
    required this.createdAt,
  });

  FinancialTransaction copyWith({
    int? id,
    String? title,
    double? amount,
    String? type,
    String? date,
    int? categoryId,
    bool? isPaid,
    String? createdAt,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      isPaid: isPaid ?? this.isPaid,
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
      'categoryId': categoryId,
      'isPaid': isPaid ? 1 : 0,
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
      categoryId: map['categoryId'],
      isPaid: map['isPaid'] == 1,
      createdAt: map['createdAt'],
    );
  }
}
