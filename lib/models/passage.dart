import 'dart:convert';

class Question {
  final int id;
  final String questionText;
  final Map<String, String> options;
  final String correctOption;
  final String explanation;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOption,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'] as Map<String, dynamic>;
    final options = optionsRaw.map((k, v) => MapEntry(k, v.toString()));
    return Question(
      id: (json['id'] ?? 0) as int,
      questionText: (json['question_text'] ?? '') as String,
      options: options,
      correctOption: (json['correct_option'] ?? 'A') as String,
      explanation: (json['explanation'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'options': options,
      'correct_option': correctOption,
      'explanation': explanation,
    };
  }
}

class Passage {
  final String id;
  final String passageText;
  final int difficultyLevel;
  final List<String> vocabularyUsed;
  final List<Question> questions;
  final DateTime createdAt;

  Passage({
    required this.id,
    required this.passageText,
    required this.difficultyLevel,
    required this.vocabularyUsed,
    required this.questions,
    required this.createdAt,
  });

  factory Passage.fromJson(Map<String, dynamic> json) {
    final dynamic rawQaJson = json['qa_json'];
    final Map<String, dynamic> qaMap = rawQaJson is String 
        ? jsonDecode(rawQaJson) as Map<String, dynamic>
        : (rawQaJson as Map<String, dynamic>? ?? {'questions': []});

    final List<dynamic> questionsRaw = qaMap['questions'] as List<dynamic>? ?? [];
    final questions = questionsRaw.map((q) => Question.fromJson(q as Map<String, dynamic>)).toList();

    return Passage(
      id: json['id'] as String,
      passageText: json['passage_text'] as String,
      difficultyLevel: json['difficulty_level'] as int,
      vocabularyUsed: List<String>.from(json['vocabulary_used'] ?? []),
      questions: questions,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passage_text': passageText,
      'difficulty_level': difficultyLevel,
      'vocabulary_used': vocabularyUsed,
      'qa_json': {
        'questions': questions.map((q) => q.toJson()).toList(),
      },
      'created_at': createdAt.toIso8601String(),
    };
  }
}
