import 'package:flutter/material.dart';
import 'package:qataly/models/passage.dart';
import 'package:qataly/models/progress.dart';
import 'package:qataly/services/supabase_service.dart';
import 'package:qataly/services/gemini_service.dart';

class ChallengeProvider extends ChangeNotifier {
  List<Passage> _availablePassages = [];
  Passage? _currentPassage;
  int _currentQuestionIndex = 0;
  final Map<int, String> _selectedAnswers = {};

  bool _isLoading = false;
  String? _errorMessage;
  UserProgress? _lastProgressResult;
  UserProgress? _todayProgress;

  List<Passage> get availablePassages => _availablePassages;
  Passage? get currentPassage => _currentPassage;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<int, String> get selectedAnswers => _selectedAnswers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserProgress? get lastProgressResult => _lastProgressResult;
  UserProgress? get todayProgress => _todayProgress;
  bool get completedToday => _todayProgress != null;

  /// Map raw exceptions to short, user-friendly Arabic messages instead of
  /// leaking raw API bodies (e.g. "Groq API Error 500: {...}").
  String _friendlyError(Object e) {
    final raw = e.toString().replaceAll('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host') ||
        lower.contains('connection refused') ||
        lower.contains('network') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return 'اتصال الإنترنت ضعيف أو منقطع. تأكد من الشبكة وحاول مرة أخرى.';
    }
    if (lower.contains('429') || lower.contains('rate limit')) {
      return 'خوادم الذكاء الاصطناعي مشغولة الآن. انتظر لحظات وحاول مرة أخرى.';
    }
    if (lower.contains('groq') || lower.contains('gemini') || lower.contains('api error')) {
      return 'تعذر توليد التحدي من الذكاء الاصطناعي. حاول مرة أخرى.';
    }
    return raw.length > 120 ? 'حدث خطأ غير متوقع. حاول مرة أخرى.' : raw;
  }

  /// Calculate student difficulty level (1-5) based on MMR
  int _calculateDifficulty(int mmr) {
    if (mmr < 800) return 1;
    if (mmr < 1000) return 2;
    if (mmr < 1300) return 3;
    if (mmr < 1600) return 4;
    return 5;
  }

  /// Check whether the student already solved a challenge today (Arena gate).
  Future<void> checkDailyCompletion(String userId) async {
    try {
      _todayProgress = await SupabaseService.instance.getTodayProgress(userId);
    } catch (_) {
      // Network failure — keep the previous state rather than blocking play.
    }
    notifyListeners();
  }

  /// On-The-Fly AI Generation: Generate a brand new passage + 6 MCQs tailored to student MMR
  Future<bool> startDynamicChallenge(int studentMmr) async {
    _isLoading = true;
    _errorMessage = null;
    _lastProgressResult = null;
    _selectedAnswers.clear();
    _currentQuestionIndex = 0;
    notifyListeners();

    try {
      final difficultyLevel = _calculateDifficulty(studentMmr);

      // 1. Generate via Gemini 3.5 Flash (6 questions)
      final rawData = await GeminiService.instance.generatePassage(
        difficultyLevel: difficultyLevel,
        numQuestions: 6,
      );

      // 2. Save directly to Supabase production database to obtain UUID & make it available
      final passage = await SupabaseService.instance.savePassage(rawData);

      _currentPassage = passage;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchPassages(int mmr) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _availablePassages = await SupabaseService.instance.getAvailablePassages(mmr);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  void startChallenge(Passage passage) {
    _currentPassage = passage;
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    _lastProgressResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  void selectOption(int questionId, String option) {
    _selectedAnswers[questionId] = option;
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentPassage != null && _currentQuestionIndex < _currentPassage!.questions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  void prevQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Jump directly to a question (progress dots navigation).
  void goToQuestion(int index) {
    if (_currentPassage == null) return;
    if (index >= 0 && index < _currentPassage!.questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  Future<UserProgress?> submitChallenge(String userId) async {
    if (_currentPassage == null || userId.isEmpty) return null;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Calculate score percentage
    int correctCount = 0;
    for (var q in _currentPassage!.questions) {
      if (_selectedAnswers[q.id] == q.correctOption) {
        correctCount++;
      }
    }
    
    final double score = (_currentPassage!.questions.isEmpty)
        ? 0.0
        : (correctCount / _currentPassage!.questions.length) * 100.0;

    try {
      _lastProgressResult = await SupabaseService.instance.logProgress(
        userId,
        _currentPassage!.id,
        score,
      );

      // Record weak words if score < 100%
      if (score < 100.0) {
        for (var word in _currentPassage!.vocabularyUsed) {
          try {
            await SupabaseService.instance.recordWeakWord(userId, word);
          } catch (_) {}
        }
      }

      _isLoading = false;
      notifyListeners();
      return _lastProgressResult;
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void reset() {
    _currentPassage = null;
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    _lastProgressResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Real-time live AI translation of double-tapped words using Gemini 3.5 Flash API
  Future<String> translateWordWithAI(String word) async {
    try {
      final contextText = _currentPassage?.passageText;
      return await GeminiService.instance.translateWord(word, passageContext: contextText);
    } catch (e) {
      return '❌ تعذر الحصول على الترجمة من الذكاء الاصطناعي.\n${_friendlyError(e)}';
    }
  }

  /// AI Grammar and Essay correction method
  Future<Map<String, dynamic>> correctJournalWithAI(String text) async {
    final result = await GeminiService.instance.correctJournalEssay(text);
    final score = (result['score'] as num?)?.toInt() ?? 80;
    final mmrGain = (score / 10).round();
    return {
      'corrected': result['corrected'] ?? text,
      'explanation': result['explanation'] ?? 'تم الفحص بنجاح.',
      'score': score,
      'mmr_gain': mmrGain,
    };
  }

  @visibleForTesting
  void setPassageForTesting(Passage passage) {
    _currentPassage = passage;
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    notifyListeners();
  }
}
