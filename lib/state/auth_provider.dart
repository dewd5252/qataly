import 'package:flutter/material.dart';
import 'package:qataly/models/profile.dart';
import 'package:qataly/services/supabase_service.dart';
import 'package:qataly/services/telegram_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  Profile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _initSession();
  }

  Future<void> _initSession() async {
    // Wait for Supabase to restore the persisted session from disk
    await SupabaseService.instance.initialSession;
    final user = SupabaseService.instance.currentAuthUser;
    if (user != null) {
      await restoreSession(user.id);
    }
  }

  Future<bool> restoreSession(String userId) async {
    // Retry on transient network failures so an authenticated user
    // isn't sent to the login screen by a momentary error.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        _currentUser = await SupabaseService.instance.getProfile(userId);
        notifyListeners();
        return _currentUser != null;
      } catch (_) {
        if (attempt == 1) return false;
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    return false;
  }

  Profile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = await SupabaseService.instance.signIn(email, password);
      _currentUser = await SupabaseService.instance.getProfile(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = await SupabaseService.instance.signUp(email, password, fullName);
      _currentUser = await SupabaseService.instance.getProfile(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login or auto-register via Telegram OAuth data.
  /// Creates a deterministic Supabase account tied to the Telegram ID.
  Future<bool> loginWithTelegram(TelegramUser tgUser) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final email = tgUser.supabaseEmail;
    final password = tgUser.supabasePassword;
    final fullName = tgUser.fullName;

    try {
      // Try sign-in first (existing user)
      final userId =
          await SupabaseService.instance.signIn(email, password);
      _currentUser = await SupabaseService.instance.getProfile(userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      // First-time user — auto-register
      try {
        final userId =
            await SupabaseService.instance.signUp(email, password, fullName);
        _currentUser = await SupabaseService.instance.getProfile(userId);
        _isLoading = false;
        notifyListeners();
        return true;
      } catch (e) {
        _errorMessage =
            'تعذّر إنشاء حسابك: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }
  }

  Future<void> refreshProfile() async {
    if (_currentUser == null) return;
    try {
      _currentUser = await SupabaseService.instance.getProfile(_currentUser!.id);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> joinClass(String schoolCode) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await SupabaseService.instance.joinClassroom(_currentUser!.id, schoolCode);
      if (success) {
        await refreshProfile();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> claimCode(String code) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await SupabaseService.instance.claimActivationCode(_currentUser!.id, code);
      if (success) {
        await refreshProfile();
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update the local MMR AND persist it to Supabase so the gain survives
  /// refreshes (journal corrections use this — challenge MMR is server-side).
  Future<void> updateUserMMR(int newMmr) async {
    if (_currentUser == null) return;
    final clamped = newMmr < 400 ? 400 : newMmr;
    _currentUser = Profile(
      id: _currentUser!.id,
      fullName: _currentUser!.fullName,
      classroomId: _currentUser!.classroomId,
      mmr: clamped,
      dailyStreak: _currentUser!.dailyStreak,
      lastActiveDate: _currentUser!.lastActiveDate,
      isPremium: _currentUser!.isPremium,
      premiumUntil: _currentUser!.premiumUntil,
      createdAt: _currentUser!.createdAt,
    );
    notifyListeners();
    try {
      await SupabaseService.instance.updateProfileMmr(_currentUser!.id, clamped);
    } catch (_) {
      // Local update already applied; persistence failure shouldn't block UX.
    }
  }

  void signOut() => logout();

  void logout() async {
    await SupabaseService.instance.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
