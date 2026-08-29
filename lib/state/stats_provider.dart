import 'package:flutter/material.dart';
import 'package:qataly/models/profile.dart';
import 'package:qataly/models/vocab_weakness.dart';
import 'package:qataly/services/supabase_service.dart';

class StatsProvider extends ChangeNotifier {
  List<VocabularyWeakness> _weakWords = [];
  List<Profile> _classroomLeaderboard = [];
  List<Profile> _globalLeaderboard = [];
  List<Map<String, dynamic>> _topClassWeakWords = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _myGlobalRank;

  List<VocabularyWeakness> get weakWords => _weakWords;
  List<Profile> get classroomLeaderboard => _classroomLeaderboard;
  List<Profile> get globalLeaderboard => _globalLeaderboard;
  List<Map<String, dynamic>> get topClassWeakWords => _topClassWeakWords;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get myGlobalRank => _myGlobalRank;

  Future<void> loadWeakWords(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _weakWords = await SupabaseService.instance.getWeakWords(userId);
    } catch (_) {
      _errorMessage = 'تعذر تحميل قاموس الضعف. اسحب للأسفل للتحديث.';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// "أتقنتها": remove a mastered word from the local list and the DB.
  /// Returns the removed item so the caller can offer an undo.
  Future<VocabularyWeakness?> masterWeakWord(String userId, String word) async {
    final index = _weakWords.indexWhere((w) => w.word == word);
    if (index == -1) return null;
    final removed = _weakWords.removeAt(index);
    notifyListeners();
    try {
      await SupabaseService.instance.removeWeakWord(userId, word);
    } catch (_) {
      // Restore locally if the delete failed server-side.
      _weakWords.insert(index, removed);
      notifyListeners();
      return null;
    }
    return removed;
  }

  /// Undo helper for masterWeakWord (re-record the word with its old count).
  Future<void> restoreWeakWord(String userId, VocabularyWeakness item) async {
    _weakWords.add(item);
    notifyListeners();
    try {
      await SupabaseService.instance.recordWeakWordRestore(userId, item);
    } catch (_) {}
  }

  Future<void> loadGlobalLeaderboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _globalLeaderboard = await SupabaseService.instance.getGlobalLeaderboard(limit: 20);
    } catch (_) {
      _errorMessage = 'تعذر تحميل الصدارة. اسحب للأسفل للتحديث.';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Global rank of the current student (shown when outside the top 20).
  Future<void> loadMyGlobalRank(int mmr) async {
    try {
      _myGlobalRank = await SupabaseService.instance.getGlobalRank(mmr);
    } catch (_) {
      _myGlobalRank = null;
    }
    notifyListeners();
  }

  Future<void> loadClassroomData(String classroomId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _classroomLeaderboard = await SupabaseService.instance.getLeaderboard(classroomId);
    } catch (_) {
      _errorMessage = 'تعذر تحميل بيانات الفصل.';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Real aggregation of the class's weakest words (replaces the old
  /// hardcoded placeholder). Requires the top_weak_words RPC.
  Future<void> loadTopClassWeakWords(String classroomId) async {
    try {
      _topClassWeakWords = await SupabaseService.instance.getTopWeakWords(classroomId);
    } catch (_) {
      _topClassWeakWords = [];
    }
    notifyListeners();
  }

  // Computed helper getters for Teacher Dashboard
  int get totalActiveStudents => _classroomLeaderboard.length;

  double get averageMmr {
    if (_classroomLeaderboard.isEmpty) return 0.0;
    final total = _classroomLeaderboard.fold<int>(0, (sum, student) => sum + student.mmr);
    return total / _classroomLeaderboard.length;
  }

  double get averageStreak {
    if (_classroomLeaderboard.isEmpty) return 0.0;
    final total = _classroomLeaderboard.fold<int>(0, (sum, student) => sum + student.dailyStreak);
    return total / _classroomLeaderboard.length;
  }
}
