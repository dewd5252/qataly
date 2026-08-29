import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class MockDb {
  static final MockDb instance = MockDb._();
  MockDb._();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // In-memory DB representation
  List<Map<String, dynamic>> classrooms = [];
  List<Map<String, dynamic>> profiles = [];
  List<Map<String, dynamic>> passages = [];
  List<Map<String, dynamic>> userProgress = [];
  List<Map<String, dynamic>> vocabularyWeaknesses = [];
  List<Map<String, dynamic>> activationCodes = [];

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    
    // Load or seed tables
    _loadOrSeedClassrooms();
    _loadOrSeedPassages();
    _loadOrSeedActivationCodes();
    _loadOrSeedProfiles();
    _loadProgress();
    _loadWeakWords();
    
    _isInitialized = true;
  }

  void _loadOrSeedClassrooms() {
    final raw = _prefs.getString('classroom_table');
    if (raw != null) {
      classrooms = List<Map<String, dynamic>>.from(jsonDecode(raw));
    } else {
      classrooms = [
        {
          'id': 'c1111111-1111-1111-1111-111111111111',
          'teacher_name': 'مستر محمد علي',
          'school_code': 'ALI2026',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'c2222222-2222-2222-2222-222222222222',
          'teacher_name': 'مستر أحمد حسن',
          'school_code': 'HASSAN88',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
      _saveTable('classroom_table', classrooms);
    }
  }

  void _loadOrSeedPassages() {
    final raw = _prefs.getString('passage_table');
    if (raw != null) {
      passages = List<Map<String, dynamic>>.from(jsonDecode(raw));
    } else {
      passages = [
        {
          'id': 'a1111111-1111-1111-1111-111111111111',
          'passage_text': 'Technology has undeniably altered the landscape of modern education. In the past, pupils relied strictly on printed textbooks, whereas today, digital libraries and AI tools offer instantaneous access to vast repositories of knowledge. However, this digital paradigm shift introduces new pedagogical challenges. Educators must ensure students develop critical thinking rather than relying on automated essay generation tools. Achieving this requires a balanced methodology incorporating traditional reasoning with modern utilities.',
          'difficulty_level': 3,
          'vocabulary_used': ['paradigm', 'pedagogical', 'repositories'],
          'qa_json': jsonEncode({
            'questions': [
              {
                'id': 1,
                'question_text': 'What is the main idea of the passage?',
                'options': {
                  'A': 'AI will completely replace traditional teachers soon.',
                  'B': 'Technology has changed education, requiring a balance with critical thinking.',
                  'C': 'Digital libraries are inferior to printed textbooks.',
                  'D': 'Educational challenges cannot be resolved by modern tools.'
                },
                'correct_option': 'B',
                'explanation': 'الممر دة بيتكلم عن إزاي التكنولوجيا غيرت التعليم بس لازم نوازن بينها وبين التفكير النقدي علشان الطالب ميعتمدش كلياً على الـ AI. الإجابة (B) هي الوحيدة اللي بتعبر عن التوازن دة بالظبط.'
              },
              {
                'id': 2,
                'question_text': 'What does the word "pedagogical" most likely mean in the context of the text?',
                'options': {
                  'A': 'Related to health and medicine.',
                  'B': 'Related to teaching and education.',
                  'C': 'Related to building materials.',
                  'D': 'Related to engineering calculations.'
                },
                'correct_option': 'B',
                'explanation': 'كلمة pedagogical جاية من pedagogy وهي علم التدريس أو أصول التربية. السياق بيتكلم عن تحديات تعليمية (pedagogical challenges)، فبالتالي معناها متعلق بالتعليم والتدريس (B).'
              }
            ]
          }),
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'a2222222-2222-2222-2222-222222222222',
          'passage_text': 'The Industrial Revolution marked a major turning point in human history, transitioning agrarian societies into mechanized industrial powerhouses. Beginning in Great Britain in the late 18th century, it rapidly disseminated across the globe. While it catalyzed unprecedented economic growth, it also precipitated massive urbanization, resulting in deplorable living conditions for the working class. The discrepancy between the affluent factory owners and impoverished laborers sparked early labor unions.',
          'difficulty_level': 4,
          'vocabulary_used': ['disseminated', 'precipitated', 'deplorable', 'discrepancy', 'affluent'],
          'qa_json': jsonEncode({
            'questions': [
              {
                'id': 1,
                'question_text': 'What initiated the formation of early labor unions?',
                'options': {
                  'A': 'The transition from Great Britain to other global nations.',
                  'B': 'The bad weather during the 18th century.',
                  'C': 'The huge discrepancy between wealthy owners and poor workers.',
                  'D': 'The massive reduction in agricultural production.'
                },
                'correct_option': 'C',
                'explanation': 'القطعة بتقول في نهايتها إن الفجوة (discrepancy) بين الأغنياء (affluent) والفقراء (impoverished) هي اللي أشعلت فكرة النقابات العمالية الأولى. عشان كدة الإجابة هي (C).'
              },
              {
                'id': 2,
                'question_text': 'Which word in the text means "spread widely"?',
                'options': {
                  'A': 'disseminated',
                  'B': 'precipitated',
                  'C': 'deplorable',
                  'D': 'transitioning'
                },
                'correct_option': 'A',
                'explanation': 'كلمة disseminated تعني انتشر أو شاع على نطاق واسع، والقطعة بتقول إن الثورة انتشرت بسرعة عبر العالم. باقي الكلمات ليها معاني تانية (precipitated يعني عجّل بحدوث شيء، deplorable يعني رث أو مزري).'
              }
            ]
          }),
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'a3333333-3333-3333-3333-333333333333',
          'passage_text': 'Language acquisition has long intrigued researchers. Skinner proposed that language is acquired through behaviorist reinforcement, whereas Chomsky argued for an innate Universal Grammar, suggesting human brains are pre-wired for language. Modern cognitive scientists adopt a connectionist view, arguing that statistical learning from environment exposure shapes linguistic competence. This dispute remains a cornerstone of cognitive science.',
          'difficulty_level': 5,
          'vocabulary_used': ['acquisition', 'innate', 'competence', 'behaviorist', 'reinforcement'],
          'qa_json': jsonEncode({
            'questions': [
              {
                'id': 1,
                'question_text': 'What is Chomsky’s primary claim regarding language?',
                'options': {
                  'A': 'Language is learned purely through positive reinforcement.',
                  'B': 'Language is an innate, biologically pre-wired capacity in humans.',
                  'C': 'Language development is completely random and unpredictable.',
                  'D': 'Language is acquired through modern engineering devices.'
                },
                'correct_option': 'B',
                'explanation': 'تشومسكي (Chomsky) مشهور بنظرية النحو العالمي الفطري (innate Universal Grammar) وإن عقل الإنسان مهيأ جينياً للغة. دة معناه إنها قدرة فطرية (B).'
              }
            ]
          }),
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'a4444444-4444-4444-4444-444444444444',
          'passage_text': 'The solar system is a vast and interesting place. It has eight planets orbiting the Sun. Earth is the third planet and the only one known to support life. The inner planets, like Mars and Venus, are rocky. The outer planets, like Jupiter and Saturn, are gas giants. Astronauts dream of exploring Mars one day to search for evidence of frozen water.',
          'difficulty_level': 1,
          'vocabulary_used': ['orbiting', 'support', 'evidence'],
          'qa_json': jsonEncode({
            'questions': [
              {
                'id': 1,
                'question_text': 'How many planets are in our solar system?',
                'options': {
                  'A': 'Five',
                  'B': 'Eight',
                  'C': 'Ten',
                  'D': 'Twelve'
                },
                'correct_option': 'B',
                'explanation': 'سؤال مباشر جداً، القطعة بتقول بشكل صريح "It has eight planets orbiting the Sun". الإجابة هي (B).'
              }
            ]
          }),
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'a5555555-5555-5555-5555-555555555555',
          'passage_text': 'Exercising daily is vital for maintaining physical health. People who walk or jog every morning have better heart rate efficiency. In addition to physical benefits, exercise releases chemicals in the brain called endorphins, which make you feel happy. Doctors recommend at least thirty minutes of active movement daily.',
          'difficulty_level': 2,
          'vocabulary_used': ['vital', 'efficiency', 'recommend'],
          'qa_json': jsonEncode({
            'questions': [
              {
                'id': 1,
                'question_text': 'What chemical does the brain release during exercise?',
                'options': {
                  'A': 'Water',
                  'B': 'Adrenaline',
                  'C': 'Endorphins',
                  'D': 'Glucose'
                },
                'correct_option': 'C',
                'explanation': 'القطعة بتقول إن التمارين بتخلي المخ يفرز مواد كيميائية اسمها "endorphins" ودي المسؤولة عن تحسين المزاج والإحساس بالسعادة. الإجابة (C).'
              }
            ]
          }),
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
      _saveTable('passage_table', passages);
    }
  }

  void _loadOrSeedActivationCodes() {
    final raw = _prefs.getString('activation_codes_table');
    if (raw != null) {
      activationCodes = List<Map<String, dynamic>>.from(jsonDecode(raw));
    } else {
      activationCodes = [
        {'code': 'VIP-30DAYS', 'duration_days': 30, 'claimed_by': null, 'claimed_at': null, 'created_at': DateTime.now().toIso8601String()},
        {'code': 'CODE-15D', 'duration_days': 15, 'claimed_by': null, 'claimed_at': null, 'created_at': DateTime.now().toIso8601String()},
        {'code': 'FREE-WEEK', 'duration_days': 7, 'claimed_by': null, 'claimed_at': null, 'created_at': DateTime.now().toIso8601String()},
        {'code': 'QATALY-SUPER', 'duration_days': 90, 'claimed_by': null, 'claimed_at': null, 'created_at': DateTime.now().toIso8601String()},
      ];
      _saveTable('activation_codes_table', activationCodes);
    }
  }

  void _loadOrSeedProfiles() {
    final raw = _prefs.getString('profile_table');
    if (raw != null) {
      profiles = List<Map<String, dynamic>>.from(jsonDecode(raw));
    } else {
      // Default offline student profile
      profiles = [
        {
          'id': 'demo-student-id',
          'full_name': 'عمر الشريف',
          'classroom_id': 'c1111111-1111-1111-1111-111111111111',
          'mmr': 1000,
          'daily_streak': 3,
          'last_active_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10), // Yesterday
          'is_premium': false,
          'premium_until': null,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'top-student-1',
          'full_name': 'رنا أحمد',
          'classroom_id': 'c1111111-1111-1111-1111-111111111111',
          'mmr': 1550,
          'daily_streak': 15,
          'last_active_date': DateTime.now().toIso8601String().substring(0, 10),
          'is_premium': true,
          'premium_until': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'top-student-2',
          'full_name': 'يوسف خالد',
          'classroom_id': 'c1111111-1111-1111-1111-111111111111',
          'mmr': 1320,
          'daily_streak': 8,
          'last_active_date': DateTime.now().toIso8601String().substring(0, 10),
          'is_premium': false,
          'premium_until': null,
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
      _saveTable('profile_table', profiles);
    }
  }

  void _loadProgress() {
    final raw = _prefs.getString('user_progress_table');
    if (raw != null) {
      userProgress = List<Map<String, dynamic>>.from(jsonDecode(raw));
    } else {
      userProgress = [];
    }
  }

  void _loadWeakWords() {
    final raw = _prefs.getString('vocabulary_weaknesses_table');
    if (raw != null) {
      vocabularyWeaknesses = List<Map<String, dynamic>>.from(jsonDecode(raw));
    } else {
      vocabularyWeaknesses = [];
    }
  }

  // Save changes helper
  void _saveTable(String key, List<Map<String, dynamic>> data) {
    _prefs.setString(key, jsonEncode(data));
  }

  // --- Logic Implementations (Simulating PostgreSQL Functionalities) ---

  // Simulating the trigger logic BEFORE INSERT ON user_progress
  Future<Map<String, dynamic>> solvePassage(String userId, String passageId, double scorePercentage) async {
    await init();
    
    // 1. Fetch classroom student profile
    final studentIdx = profiles.indexWhere((p) => p['id'] == userId);
    if (studentIdx == -1) throw Exception("الطالب غير موجود!");
    final student = profiles[studentIdx];

    // 2. Fetch passage
    final passageIdx = passages.indexWhere((p) => p['id'] == passageId);
    if (passageIdx == -1) throw Exception("القطعة غير موجودة!");
    final passage = passages[passageIdx];

    final int oldMmr = student['mmr'] as int;
    final int difficulty = passage['difficulty_level'] as int;
    final int difficultyMmr = 600 + (difficulty * 200);

    // 3. Expected score
    final double expectedScore = 1.0 / (1.0 + pow(10.0, (difficultyMmr - oldMmr) / 400.0));
    final double actualScore = scorePercentage / 100.0;

    // 4. Calculate new MMR (K-Factor = 32)
    final int kFactor = 32;
    int newMmr = oldMmr + (kFactor * (actualScore - expectedScore)).round();
    if (newMmr < 400) newMmr = 400;

    // 5. Streak Update
    final String todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final String yesterdayStr = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final String lastActive = student['last_active_date'] ?? '';

    int currentStreak = student['daily_streak'] ?? 0;

    if (lastActive == todayStr) {
      // Already solved today, MMR changes but streak stays same
    } else if (lastActive == yesterdayStr) {
      currentStreak += 1;
    } else {
      currentStreak = 1; // reset or broke streak
    }

    // 6. Update student profile table
    profiles[studentIdx] = {
      ...student,
      'mmr': newMmr,
      'daily_streak': currentStreak,
      'last_active_date': todayStr,
    };
    _saveTable('profile_table', profiles);

    // 7. Add weak words if score < 100%
    if (scorePercentage < 100.0) {
      final List<dynamic> words = passage['vocabulary_used'] ?? [];
      for (var w in words) {
        _addWeakWordOffline(userId, w.toString());
      }
    }

    // 8. Insert record in user_progress table
    final newProgress = {
      'id': 'prog-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': userId,
      'passage_id': passageId,
      'score_percentage': scorePercentage,
      'old_mmr': oldMmr,
      'new_mmr': newMmr,
      'solved_at': DateTime.now().toIso8601String(),
    };
    userProgress.add(newProgress);
    _saveTable('user_progress_table', userProgress);

    return newProgress;
  }

  void _addWeakWordOffline(String userId, String word) {
    final idx = vocabularyWeaknesses.indexWhere((vw) => vw['user_id'] == userId && vw['word'].toString().toLowerCase() == word.toLowerCase());
    if (idx != -1) {
      vocabularyWeaknesses[idx] = {
        ...vocabularyWeaknesses[idx],
        'mistake_count': (vocabularyWeaknesses[idx]['mistake_count'] as int) + 1,
        'last_seen': DateTime.now().toIso8601String(),
      };
    } else {
      vocabularyWeaknesses.add({
        'id': 'vw-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000)}',
        'user_id': userId,
        'word': word,
        'mistake_count': 1,
        'last_seen': DateTime.now().toIso8601String(),
      });
    }
    _saveTable('vocabulary_weaknesses_table', vocabularyWeaknesses);
  }

  // Simulating the transaction-safe stored procedure 'claim_activation_code'
  Future<bool> claimActivationCode(String userId, String code) async {
    await init();

    // Lock simulation wait
    await Future.delayed(const Duration(milliseconds: 600));

    final codeIdx = activationCodes.indexWhere((c) => c['code'].toString().toUpperCase() == code.toUpperCase());
    if (codeIdx == -1) {
      throw Exception('هذا الكود غير صحيح!');
    }

    final codeRecord = activationCodes[codeIdx];
    if (codeRecord['claimed_by'] != null) {
      throw Exception('تم استخدام هذا الكود مسبقاً!');
    }

    final int duration = codeRecord['duration_days'] as int;

    // Update activation_codes table
    activationCodes[codeIdx] = {
      ...codeRecord,
      'claimed_by': userId,
      'claimed_at': DateTime.now().toIso8601String(),
    };
    _saveTable('activation_codes_table', activationCodes);

    // Update student profile (premium state)
    final studentIdx = profiles.indexWhere((p) => p['id'] == userId);
    if (studentIdx != -1) {
      final student = profiles[studentIdx];
      final String? currentPremiumUntilStr = student['premium_until'];
      DateTime baseDate = DateTime.now();
      if (currentPremiumUntilStr != null) {
        final currentUntil = DateTime.parse(currentPremiumUntilStr);
        if (currentUntil.isAfter(DateTime.now())) {
          baseDate = currentUntil;
        }
      }
      final newPremiumUntil = baseDate.add(Duration(days: duration));

      profiles[studentIdx] = {
        ...student,
        'is_premium': true,
        'premium_until': newPremiumUntil.toIso8601String(),
      };
      _saveTable('profile_table', profiles);
    }

    return true;
  }

  // Create new profile offline
  Future<Map<String, dynamic>> createProfile(String userId, String fullName) async {
    await init();
    final newProfile = {
      'id': userId,
      'full_name': fullName,
      'classroom_id': null,
      'mmr': 1000,
      'daily_streak': 0,
      'last_active_date': DateTime.now().toIso8601String().substring(0, 10),
      'is_premium': false,
      'premium_until': null,
      'created_at': DateTime.now().toIso8601String(),
    };
    profiles.add(newProfile);
    _saveTable('profile_table', profiles);
    return newProfile;
  }

  // Join Classroom
  Future<bool> joinClassroom(String userId, String schoolCode) async {
    await init();
    final classIdx = classrooms.indexWhere((c) => c['school_code'].toString().toUpperCase() == schoolCode.toUpperCase());
    if (classIdx == -1) {
      throw Exception('كود السنتر/المدرس غير صحيح!');
    }
    final classRecord = classrooms[classIdx];

    final studentIdx = profiles.indexWhere((p) => p['id'] == userId);
    if (studentIdx != -1) {
      profiles[studentIdx] = {
        ...profiles[studentIdx],
        'classroom_id': classRecord['id'],
      };
      _saveTable('profile_table', profiles);
      return true;
    }
    return false;
  }
}
