class AppSetting {
  final int? id;
  final String key;
  final String value;

  AppSetting({
    this.id,
    required this.key,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'key': key,
      'value': value,
    };
  }

  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      id: map['id'],
      key: map['key'],
      value: map['value'],
    );
  }
}
