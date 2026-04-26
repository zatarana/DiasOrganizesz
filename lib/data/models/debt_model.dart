class Debt {
  final int? id;
  final String title;
  final String? description;
  final double totalAmount;
  final String? creditor;
  final String status; // 'active', 'paid', 'canceled'
  final String createdAt;
  final String updatedAt;

  Debt({
    this.id,
    required this.title,
    this.description,
    required this.totalAmount,
    this.creditor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Debt copyWith({
    int? id,
    String? title,
    String? description,
    double? totalAmount,
    String? creditor,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      creditor: creditor ?? this.creditor,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'totalAmount': totalAmount,
      'creditor': creditor,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      totalAmount: map['totalAmount'],
      creditor: map['creditor'],
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
