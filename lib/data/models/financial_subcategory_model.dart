class FinancialSubcategory {
  final int? id;
  final int categoryId;
  final String name;
  final bool isDefault;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  FinancialSubcategory({
    this.id,
    required this.categoryId,
    required this.name,
    this.isDefault = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  FinancialSubcategory copyWith({
    int? id,
    int? categoryId,
    String? name,
    bool? isDefault,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return FinancialSubcategory(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'name': name,
        'isDefault': isDefault ? 1 : 0,
        'isArchived': isArchived ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FinancialSubcategory.fromMap(Map<String, dynamic> map) {
    bool asBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value == 1;
      final normalized = '$value'.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    return FinancialSubcategory(
      id: map['id'],
      categoryId: map['categoryId'] ?? 0,
      name: map['name'] ?? 'Outros',
      isDefault: asBool(map['isDefault']),
      isArchived: asBool(map['isArchived']),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
