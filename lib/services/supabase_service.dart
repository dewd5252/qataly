import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qataly/models/classroom.dart';
import 'package:qataly/models/profile.dart';
import 'package:qataly/models/passage.dart';
import 'package:qataly/models/progress.dart';
import 'package:qataly/models/vocab_weakness.dart';

/// Production-only Supabase service. No offline/demo mode.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  User? get currentAuthUser => _db.auth.currentUser;

  /// Completes once Supabase has restored the persisted session from disk.
  /// gotrue 2.x emits an `initialSession` auth event when restoration
  /// finishes (with a null session when none was stored).
  Future<Session?> get initialSession async {
    final current = _db.auth.currentSession;
    if (current != null) return current;

    try {
      final state = await _db.auth.onAuthStateChange
          .firstWhere((s) => s.event == AuthChangeEvent.initialSession)
          .timeout(const Duration(seconds: 10));
      return state.session;
    } on TimeoutException {
      return _db.auth.currentSession;
    }
  }

  // ─────────────────────────────── AUTH ───────────────────────────────

  Future<String> signIn(String email, String password) async {
    final res = await _db.auth
        .signInWithPassword(email: email, password: password);
    if (res.user == null) {
      throw Exception('البريد الإلكتروني أو كلمة المرور غير صحيحة');
    }
    return res.user!.id;
  }

  Future<String> signUp(
      String email, String password, String fullName) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    if (res.user == null) {
      throw Exception('تعذّر إنشاء الحساب. جرّب مرة أخرى.');
    }
    return res.user!.id;
  }

  Future<void> signOut() => _db.auth.signOut();

  /// Delete user account and associated records (Google Play Data Safety compliant)
  Future<void> deleteAccount(String userId) async {
    try {
      await _db.from('user_progress').delete().eq('user_id', userId);
      await _db.from('vocabulary_weaknesses').delete().eq('user_id', userId);
      await _db.from('profiles').delete().eq('id', userId);
    } catch (_) {}
    await _db.auth.signOut();
  }

  // ─────────────────────────────── PROFILES ───────────────────────────

  Future<Profile> getProfile(String userId) async {
    final data = await _db
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      // Profile may not be created yet — wait briefly and retry
      await Future.delayed(const Duration(seconds: 1));
      final retry = await _db
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (retry == null) {
        // Failsafe auto-create profile row
        final newProfile = {
          'id': userId,
          'full_name': _db.auth.currentUser?.userMetadata?['full_name'] ?? 'طالب جديد',
          'mmr': 1000,
          'daily_streak': 0,
          'last_active_date': DateTime.now().toIso8601String().split('T')[0],
          'is_premium': false,
        };
        await _db.from('profiles').insert(newProfile);
        final created = await _db.from('profiles').select().eq('id', userId).single();
        return Profile.fromJson(created);
      }
      return Profile.fromJson(retry);
    }
    return Profile.fromJson(data);
  }

  // ─────────────────────────────── CLASSROOMS ─────────────────────────

  Future<List<Classroom>> getClassrooms() async {
    final rows = await _db.from('classrooms').select();
    return (rows as List)
        .map((c) => Classroom.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<bool> joinClassroom(String userId, String schoolCode) async {
    final classroom = await _db
        .from('classrooms')
        .select('id')
        .eq('school_code', schoolCode.toUpperCase())
        .maybeSingle();

    if (classroom == null) {
      throw Exception('كود الفصل غير صحيح. تأكد من الكود وأعد المحاولة.');
    }

    await _db
        .from('profiles')
        .update({'classroom_id': classroom['id']})
        .eq('id', userId);
    return true;
  }

  // ─────────────────────────────── PASSAGES ───────────────────────────

  Future<List<Passage>> getAvailablePassages(int studentMmr) async {
    final rows = await _db
        .from('passages')
        .select()
        .order('difficulty_level');
    return (rows as List)
        .map((p) => Passage.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Save an AI-generated passage to the database.
  Future<Passage> savePassage(Map<String, dynamic> passageData) async {
    final row = await _db.from('passages').insert({
      'passage_text': passageData['passage_text'],
      'difficulty_level': passageData['difficulty_level'],
      'vocabulary_used': passageData['vocabulary_used'],
      'qa_json': {'questions': passageData['questions']},
    }).select().single();
    return Passage.fromJson(row);
  }

  // ─────────────────────────────── PROGRESS ───────────────────────────

  Future<UserProgress> logProgress(
      String userId, String passageId, double scorePercentage) async {
    final row = await _db.from('user_progress').insert({
      'user_id': userId,
      'passage_id': passageId,
      'score_percentage': scorePercentage,
    }).select().single();

    return UserProgress.fromJson(row);
  }

  /// Latest progress row solved today (local time), or null if the daily
  /// challenge has not been completed yet. Used for the Arena "done today" state.
  Future<UserProgress?> getTodayProgress(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await _db
        .from('user_progress')
        .select()
        .eq('user_id', userId)
        .gte('solved_at', startOfDay)
        .order('solved_at', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return UserProgress.fromJson(rows.first);
  }

  /// Recent progress history for one student (teacher drill-down).
  Future<List<UserProgress>> getStudentProgress(String userId,
      {int limit = 5}) async {
    final rows = await _db
        .from('user_progress')
        .select()
        .eq('user_id', userId)
        .order('solved_at', ascending: false)
        .limit(limit);
    return [for (final r in rows as List) UserProgress.fromJson(r as Map<String, dynamic>)];
  }

  // ─────────────────────────────── VOCAB ──────────────────────────────

  Future<List<VocabularyWeakness>> getWeakWords(String userId) async {
    final rows = await _db
        .from('vocabulary_weaknesses')
        .select()
        .eq('user_id', userId)
        .order('mistake_count', ascending: false);
    return (rows as List)
        .map((v) => VocabularyWeakness.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordWeakWord(String userId, String word) async {
    // Prefer the atomic increment RPC (supabase_ux_migrations.sql); it bumps
    // mistake_count instead of resetting it to 1 on every upsert.
    try {
      await _db.rpc('increment_weak_word', params: {
        'p_user_id': userId,
        'p_word': word,
      });
      return;
    } catch (_) {
      // RPC not deployed yet — fall back to plain upsert.
    }
    await _db.from('vocabulary_weaknesses').upsert(
          {
            'user_id': userId,
            'word': word,
            'mistake_count': 1,
            'last_seen': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,word',
          ignoreDuplicates: false,
        );
  }

  /// Remove a word the student has mastered ("أتقنتها").
  Future<void> removeWeakWord(String userId, String word) async {
    await _db
        .from('vocabulary_weaknesses')
        .delete()
        .eq('user_id', userId)
        .eq('word', word);
  }

  /// Undo for "أتقنتها": re-insert the word with its previous mistake count.
  Future<void> recordWeakWordRestore(String userId, VocabularyWeakness item) async {
    await _db.from('vocabulary_weaknesses').upsert(
          {
            'user_id': userId,
            'word': item.word,
            'mistake_count': item.mistakeCount,
            'last_seen': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,word',
          ignoreDuplicates: false,
        );
  }

  /// Classroom-wide weak words aggregation (real data behind the teacher
  /// dashboard card). Requires the top_weak_words RPC.
  Future<List<Map<String, dynamic>>> getTopWeakWords(String classroomId,
      {int limit = 5}) async {
    final rows = await _db.rpc('top_weak_words', params: {
      'p_classroom_id': classroomId,
      'p_limit': limit,
    });
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return {
        'word': m['word'] as String? ?? '',
        'mistakes': (m['total_mistakes'] as num?)?.toInt() ?? 0,
        'students': (m['students_count'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  // ─────────────────────────────── ACTIVATION CODES ───────────────────

  Future<bool> claimActivationCode(String userId, String code) async {
    final result = await _db.rpc('claim_activation_code', params: {
      'p_user_id': userId,
      'p_code': code.toUpperCase(),
    });
    return (result as bool?) ?? false;
  }

  // ─────────────────────────────── LEADERBOARD ────────────────────────

  Future<List<Profile>> getLeaderboard(String classroomId) async {
    final rows = await _db
        .from('profiles')
        .select()
        .eq('classroom_id', classroomId)
        .order('mmr', ascending: false);
    return (rows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<List<Profile>> getGlobalLeaderboard({int limit = 20}) async {
    final rows = await _db
        .from('profiles')
        .select()
        .order('mmr', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((p) => Profile.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Global rank of a student = 1 + number of profiles with higher MMR.
  /// Used for the "your rank" card when the student is outside the top list.
  Future<int> getGlobalRank(int mmr) async {
    final res = await _db
        .from('profiles')
        .select('id')
        .gt('mmr', mmr)
        .count();
    return res.count + 1;
  }

  /// Persist an MMR change to the student's own profile (journal gains).
  Future<void> updateProfileMmr(String userId, int newMmr) async {
    await _db
        .from('profiles')
        .update({'mmr': newMmr < 400 ? 400 : newMmr})
        .eq('id', userId);
  }
}
