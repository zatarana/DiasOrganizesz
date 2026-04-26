class Project {
  final int? id;
  final String name;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String status; // active, completed, paused, canceled
  final String createdAt;
  final String updatedAt;

  Project({
    this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      startDate: map['startDate'],
      endDate: map['endDate'],
      status: map['status'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Project copyWith({
    int? id,
    String? name,
    String? description,
    String? startDate,
    String? endDate,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
