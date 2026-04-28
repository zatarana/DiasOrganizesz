class CreditCard {
  final int? id;
  final String name;
  final String? issuer;
  final double creditLimit;
  final int closingDay;
  final int dueDay;
  final int? paymentAccountId;
  final String color;
  final String icon;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  CreditCard({
    this.id,
    required this.name,
    this.issuer,
    this.creditLimit = 0,
    required this.closingDay,
    required this.dueDay,
    this.paymentAccountId,
    this.color = '0xFF673AB7',
    this.icon = 'credit_card',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CreditCard copyWith({
    int? id,
    String? name,
    String? issuer,
    bool clearIssuer = false,
    double? creditLimit,
    int? closingDay,
    int? dueDay,
    int? paymentAccountId,
    bool clearPaymentAccountId = false,
    String? color,
    String? icon,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return CreditCard(
      id: id ?? this.id,
      name: name ?? this.name,
      issuer: clearIssuer ? null : (issuer ?? this.issuer),
      creditLimit: creditLimit ?? this.creditLimit,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
      paymentAccountId: clearPaymentAccountId ? null : (paymentAccountId ?? this.paymentAccountId),
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'issuer': issuer,
        'creditLimit': creditLimit,
        'closingDay': closingDay,
        'dueDay': dueDay,
        'paymentAccountId': paymentAccountId,
        'color': color,
        'icon': icon,
        'isArchived': isArchived ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory CreditCard.fromMap(Map<String, dynamic> map) {
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

    return CreditCard(
      id: map['id'],
      name: map['name'] ?? 'Cartão sem nome',
      issuer: map['issuer'],
      creditLimit: asDouble(map['creditLimit']),
      closingDay: map['closingDay'] ?? 1,
      dueDay: map['dueDay'] ?? 10,
      paymentAccountId: map['paymentAccountId'],
      color: map['color'] ?? '0xFF673AB7',
      icon: map['icon'] ?? 'credit_card',
      isArchived: asBool(map['isArchived']),
      createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
    );
  }
}
