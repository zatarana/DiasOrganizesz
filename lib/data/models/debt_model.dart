class Debt {
  final int? id;
  final String name; // Formerly title
  final String? description;
  final double totalAmount;
  final double? installmentAmount;
  final int? installmentCount;
  final String? startDate;
  final String? firstDueDate;
  final int? categoryId;
  final String? creditorName;
  final String status; // 'active', 'paid', 'overdue', 'paused', 'canceled'
  final String? notes;
  final String createdAt;
  final String updatedAt;

  Debt({
    this.id,
    required this.name,
    this.description,
    required this.totalAmount,
    this.installmentAmount,
    this.installmentCount,
    this.startDate,
    this.firstDueDate,
    this.categoryId,
    this.creditorName,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Debt copyWith({
    int? id,
    String? name,
    String? description,
    double? totalAmount,
    double? installmentAmount,
    int? installmentCount,
    String? startDate,
    String? firstDueDate,
    int? categoryId,
    String? creditorName,
    String? status,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      installmentCount: installmentCount ?? this.installmentCount,
      startDate: startDate ?? this.startDate,
      firstDueDate: firstDueDate ?? this.firstDueDate,
      categoryId: categoryId ?? this.categoryId,
      creditorName: creditorName ?? this.creditorName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'totalAmount': totalAmount,
      'installmentAmount': installmentAmount,
      'installmentCount': installmentCount,
      'startDate': startDate,
      'firstDueDate': firstDueDate,
      'categoryId': categoryId,
      'creditorName': creditorName,
      'status': status,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      name: map['name'] ?? map['title'] ?? 'Dívida sem nome',
      description: map['description'],
      totalAmount: map['totalAmount'] ?? 0.0,
      installmentAmount: map['installmentAmount'] ?? map['installmentValue'],
      installmentCount: map['installmentCount'] ?? map['installmentsCount'],
      startDate: map['startDate'],
      firstDueDate: map['firstDueDate'],
      categoryId: map['categoryId'],
      creditorName: map['creditorName'] ?? map['creditor'],
      status: map['status'] ?? 'active',
      notes: map['notes'],
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}

