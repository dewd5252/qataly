class Profile {
  final String id;
  final String fullName;
  final String? classroomId;
  final int mmr;
  final int dailyStreak;
  final String lastActiveDate;
  final bool isPremium;
  final DateTime? premiumUntil;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.fullName,
    this.classroomId,
    required this.mmr,
    required this.dailyStreak,
    required this.lastActiveDate,
    required this.isPremium,
    this.premiumUntil,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: (json['full_name'] ?? 'طالب جديد') as String,
      classroomId: json['classroom_id'] as String?,
      mmr: (json['mmr'] ?? 1000) as int,
      dailyStreak: (json['daily_streak'] ?? 0) as int,
      lastActiveDate: (json['last_active_date'] ?? '') as String,
      isPremium: (json['is_premium'] ?? false) as bool,
      premiumUntil: json['premium_until'] != null ? DateTime.parse(json['premium_until'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'classroom_id': classroomId,
      'mmr': mmr,
      'daily_streak': dailyStreak,
      'last_active_date': lastActiveDate,
      'is_premium': isPremium,
      'premium_until': premiumUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get rank {
    if (mmr < 600) return 'Bronze I';
    if (mmr < 800) return 'Bronze II';
    if (mmr < 1000) return 'Silver I';
    if (mmr < 1200) return 'Silver II';
    if (mmr < 1400) return 'Gold I';
    if (mmr < 1600) return 'Gold II';
    if (mmr < 1800) return 'Diamond I';
    return 'Diamond II (Master)';
  }
}
