class Classroom {
  final String id;
  final String teacherName;
  final String schoolCode;
  final DateTime createdAt;

  Classroom({
    required this.id,
    required this.teacherName,
    required this.schoolCode,
    required this.createdAt,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'] as String,
      teacherName: json['teacher_name'] as String,
      schoolCode: json['school_code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_name': teacherName,
      'school_code': schoolCode,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
