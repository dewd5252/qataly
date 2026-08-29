class ActivationCode {
  final String code;
  final int durationDays;
  final String? claimedBy;
  final DateTime? claimedAt;
  final DateTime createdAt;

  ActivationCode({
    required this.code,
    required this.durationDays,
    this.claimedBy,
    this.claimedAt,
    required this.createdAt,
  });

  factory ActivationCode.fromJson(Map<String, dynamic> json) {
    return ActivationCode(
      code: json['code'] as String,
      durationDays: (json['duration_days'] ?? 30) as int,
      claimedBy: json['claimed_by'] as String?,
      claimedAt: json['claimed_at'] != null ? DateTime.parse(json['claimed_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'duration_days': durationDays,
      'claimed_by': claimedBy,
      'claimed_at': claimedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
