import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/services/supabase_service.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/screens/login_screen.dart';
import 'package:qataly/screens/student_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLoading = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    // Session restoration can take up to ~10s on slow networks; reveal a
    // loading indicator once the entrance animations have settled so the
    // user knows the app is working, not frozen.
    _loadingTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showLoading = true);
    });
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    final startTime = DateTime.now();
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Wait for Supabase to restore the persisted session from disk
    // (restoration is async; reading currentUser before this loses the session).
    await SupabaseService.instance.initialSession;

    // If currentUser is null but Supabase has an auth user, restore profile
    if (auth.currentUser == null) {
      final user = SupabaseService.instance.currentAuthUser;
      if (user != null) {
        await auth.restoreSession(user.id);
      }
    }

    // Ensure splash logo animation displays for at least 3.4 seconds
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final remaining = 3400 - elapsed;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, secondaryAnimation) =>
            auth.currentUser == null
                ? const LoginScreen()
                : const StudentDashboard(),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QatalyTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // ── Logo ──
            Image.asset(
              'assets/images/logo.jpg',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            )
                .animate()
                .scale(
                  begin: const Offset(0.3, 0.3),
                  end: const Offset(1.0, 1.0),
                  duration: 700.ms,
                  curve: Curves.elasticOut,
                )
                .fade(duration: 500.ms),

            const SizedBox(height: 32),

            // ── App name ──
            const Text(
              'قطعه',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            )
                .animate(delay: 400.ms)
                .slideY(begin: 0.5, end: 0, duration: 600.ms, curve: Curves.easeOut)
                .fade(duration: 500.ms),

            const SizedBox(height: 10),

            // ── Tagline ──
            const Text(
              'حل وتدريب على أسئلة قطعة اللغة الإنجليزية',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5B8EE6),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            )
                .animate(delay: 600.ms)
                .fade(duration: 500.ms)
                .slideY(begin: 0.3, end: 0, duration: 500.ms),

            const Spacer(flex: 2),

            // ── Loading feedback (appears after entrance animations) ──
            if (_showLoading)
              Column(
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: QatalyTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'جاري تجهيز جلستك...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ).animate().fade(duration: 400.ms),

            // ── Dev credit ──
            Column(
              children: [
                const Text(
                  '— zed32 devs / abo wehidy —',
                  style: TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 13,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                // Animated underline
                Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
                    .animate(delay: 900.ms)
                    .scaleX(begin: 0, end: 1, duration: 600.ms, curve: Curves.easeOut),
              ],
            )
                .animate(delay: 800.ms)
                .fade(duration: 700.ms),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
