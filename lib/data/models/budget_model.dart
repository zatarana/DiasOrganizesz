class Budget {
  final int? id;
  final String name;
  final int? categoryId;
  final int? subcategoryId;
  final double limitAmount;
  final String month;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  Budget({
    this.id,
    required this.name,
    this.categoryId,
    this.subcategoryId,
    required this.limitAmount,
    required this.month,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Budget copyWith({
    int? id,
    String? name,
    int? categoryId,
    bool clearCategoryId = false,
    int? subcategoryId,
    bool clearSubcategoryId = false,
    double? limitAmount,
    String? month,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategoryId ? null : (subcategoryId ?? this.subcategoryId),
      limitAmount: limitAmount ?? this.limitAmount,
      month: month ?? this.month,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'limitAmount': limitAmount,
        'month': month,
        'isArchived': isArchived ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Budget.fromMap(Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0.0;
    }

    return Budget(
      id: map['id'],
      name: map['name'] ?? 'Orçamento sem nome',
      categoryId: map['categoryId'],
      subcategoryId: map['subcategoryId'],
      limitAmount: asDouble(map['limitAmount']),
      month: map['month'] ?? DateTime.now().toIso8601String().substring(0, 7),
      isArchived: map['isArchived'] == 1,
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
