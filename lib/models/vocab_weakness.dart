class VocabularyWeakness {
  final String id;
  final String userId;
  final String word;
  final int mistakeCount;
  final DateTime lastSeen;

  VocabularyWeakness({
    required this.id,
    required this.userId,
    required this.word,
    required this.mistakeCount,
    required this.lastSeen,
  });

  factory VocabularyWeakness.fromJson(Map<String, dynamic> json) {
    return VocabularyWeakness(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      word: json['word'] as String,
      mistakeCount: (json['mistake_count'] ?? 1) as int,
      lastSeen: DateTime.parse(json['last_seen'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'word': word,
      'mistake_count': mistakeCount,
      'last_seen': lastSeen.toIso8601String(),
    };
  }
}
