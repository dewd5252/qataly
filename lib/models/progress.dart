class UserProgress {
  final String id;
  final String userId;
  final String passageId;
  final double scorePercentage;
  final int oldMmr;
  final int newMmr;
  final DateTime solvedAt;

  UserProgress({
    required this.id,
    required this.userId,
    required this.passageId,
    required this.scorePercentage,
    required this.oldMmr,
    required this.newMmr,
    required this.solvedAt,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      passageId: json['passage_id'] as String,
      scorePercentage: double.parse((json['score_percentage'] ?? 0.0).toString()),
      oldMmr: (json['old_mmr'] ?? 1000) as int,
      newMmr: (json['new_mmr'] ?? 1000) as int,
      solvedAt: DateTime.parse(json['solved_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'passage_id': passageId,
      'score_percentage': scorePercentage,
      'old_mmr': oldMmr,
      'new_mmr': newMmr,
      'solved_at': solvedAt.toIso8601String(),
    };
  }
}
