import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qataly/models/passage.dart';
import 'package:qataly/models/profile.dart';
import 'package:qataly/models/vocab_weakness.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/state/challenge_provider.dart';
import 'package:qataly/state/stats_provider.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/widgets/brutalist_widgets.dart';
import 'package:qataly/screens/challenge_screen.dart';
import 'package:qataly/screens/onboarding_screen.dart';
import 'package:qataly/screens/teacher_dashboard.dart';
import 'package:qataly/screens/legal_screen.dart';
import 'package:qataly/services/gemini_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentTab = 0;
  final _codeController = TextEditingController();
  final _classCodeController = TextEditingController();
  final _journalController = TextEditingController();
  final _vaultSearchController = TextEditingController();

  // Vault search + sort state
  bool _vaultSortByNewest = false;

  // Leaderboard scope: global (default) / classroom
  bool _leaderboardClassroomMode = false;

  // Journal correction state
  bool _isCorrectingJournal = false;
  Map<String, dynamic>? _journalResult;

  // Countdown to the next daily challenge (midnight), for the Arena done-state.
  Timer? _countdownTimer;
  int _secondsUntilMidnight = 0;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
    _vaultSearchController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        final challenge = Provider.of<ChallengeProvider>(context, listen: false);
        challenge.fetchPassages(user.mmr);
        challenge.checkDailyCompletion(user.id);
        Provider.of<StatsProvider>(context, listen: false).loadWeakWords(user.id);
      }
      Provider.of<StatsProvider>(context, listen: false).loadGlobalLeaderboard();

      // One-time intro for the gamified concepts (MMR, ranks, streak, VIP).
      OnboardingScreen.shouldShow().then((show) {
        if (show && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
      });
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    if (mounted) {
      setState(() {
        _secondsUntilMidnight = midnight.difference(now).inSeconds;
      });
    }
  }

  String _formatCountdown(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    _classCodeController.dispose();
    _journalController.dispose();
    _vaultSearchController.dispose();
    super.dispose();
  }

  void _claimCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.claimCode(code);

    if (mounted) {
      if (success) {
        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: QatalyTheme.secondary,
            content: Text(
              '🎉 تم تفعيل الحساب البريميوم بنجاح! شكراً لك.',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: QatalyTheme.accent,
            content: Text(
              auth.errorMessage ?? 'الكود غير صحيح أو مستخدم سابقاً!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  void _joinClassroom() async {
    final code = _classCodeController.text.trim();
    if (code.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.joinClass(code);

    if (mounted) {
      if (success) {
        _classCodeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: QatalyTheme.secondary,
            content: Text(
              '✅ تم الارتباط بالسنتر بنجاح!',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: QatalyTheme.accent,
            content: Text(
              auth.errorMessage ?? 'كود السنتر غير صحيح!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  void _correctJournal() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isCorrectingJournal = true;
      _journalResult = null;
    });

    try {
      final challenge = Provider.of<ChallengeProvider>(context, listen: false);
      final result = await challenge.correctJournalWithAI(text);

      if (mounted) {
        setState(() {
          _journalResult = result;
          _isCorrectingJournal = false;
        });

        if (auth.currentUser != null) {
          final mmrGain = (result['mmr_gain'] as num?)?.toInt() ?? 5;
          auth.updateUserMMR(auth.currentUser!.mmr + mmrGain);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCorrectingJournal = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: QatalyTheme.accent,
            content: Text(
              'خطأ في التصحيح: $e',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final challenge = Provider.of<ChallengeProvider>(context);
    final stats = Provider.of<StatsProvider>(context);
    final student = auth.currentUser;

    if (student == null) {
      return const Scaffold(
        backgroundColor: QatalyTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: QatalyTheme.secondary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: QatalyTheme.background,
      appBar: AppBar(
        backgroundColor: QatalyTheme.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: QatalyTheme.primary,
                border: Border.all(color: Colors.black, width: 2.0),
              ),
              child: Text(
                _getTabTitle(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: QatalyTheme.accent),
            tooltip: 'تسجيل الخروج',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildArenaTab(student, challenge),
          _buildVaultTab(student, stats),
          _buildGlobalLeaderboardTab(student, stats),
          _buildSettingsTab(student, auth),
        ],
      ),
        bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black, width: 3.0)),
          color: QatalyTheme.cardBase,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) {
            setState(() {
              _currentTab = index;
            });
            if (index == 2) {
              _refreshLeaderboard(student, stats);
            }
          },
          backgroundColor: QatalyTheme.cardBase,
          selectedItemColor: QatalyTheme.secondary,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_esports),
              label: 'الساحة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'قاموس الضعف',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard),
              label: 'الصدارة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }

  String _getTabTitle() {
    switch (_currentTab) {
      case 0:
        return 'ساحة تدريب القطعة ⚡';
      case 1:
        return 'قاموس الضعف الشخصي 📚';
      case 2:
        return _leaderboardClassroomMode ? 'صدارة الفصل 🎓' : 'أبطال قطعلي (Top 20) 🏆';
      case 3:
        return 'إعدادات الحساب ⚙️';
      default:
        return 'قطعلي ⚡';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Sub-Tab 0: Arena Tab
  // ─────────────────────────────────────────────────────────────

  int _expectedDifficulty(int mmr) {
    if (mmr < 800) return 1;
    if (mmr < 1000) return 2;
    if (mmr < 1300) return 3;
    if (mmr < 1600) return 4;
    return 5;
  }

  Future<void> _startDailyChallenge(Profile student, ChallengeProvider challenge) async {
    final success = await challenge.startDynamicChallenge(student.mmr);
    if (!mounted || !success) return; // failure renders the inline error card
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChallengeScreen()),
    );
    // The student may have just completed today's challenge — refresh the gate.
    if (mounted) challenge.checkDailyCompletion(student.id);
  }

  /// Fallback when AI generation fails: reuse a teacher/ready-made passage
  /// whose difficulty is closest to the student's level.
  void _startFallbackChallenge(Profile student, ChallengeProvider challenge) {
    final target = _expectedDifficulty(student.mmr);
    final passages = challenge.availablePassages;
    if (passages.isEmpty) return;

    Passage best = passages.first;
    int bestDiff = (passages.first.difficultyLevel - target).abs();
    for (final p in passages) {
      final d = (p.difficultyLevel - target).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = p;
      }
    }

    challenge.startChallenge(best);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChallengeScreen()),
    ).then((_) {
      if (mounted) challenge.checkDailyCompletion(student.id);
    });
  }

  Widget _buildArenaTab(Profile student, ChallengeProvider challenge) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat Badges Row
          Row(
            children: [
              Expanded(
                child: BrutalistCard(
                  backgroundColor: QatalyTheme.accent,
                  child: Column(
                    children: [
                      const Text(
                        'سلسلة الأيام 🔥',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student.dailyStreak} يوم متتالي',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BrutalistCard(
                  backgroundColor: QatalyTheme.secondary,
                  child: Column(
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          student.rank.toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'MMR: ${student.mmr}',
                          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Daily Challenge Card
          BrutalistCard(
            backgroundColor: QatalyTheme.cardBase,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تحدي القطعة اليومي ⚡',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: challenge.completedToday
                            ? QatalyTheme.primary
                            : QatalyTheme.secondary,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Text(
                        challenge.completedToday ? 'مكتمل ✅' : 'متاح الآن',
                        style: TextStyle(
                          color: challenge.completedToday ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (challenge.completedToday) ...[
                  // ── Completed state: summary + countdown to the next one ──
                  const Text(
                    'تم إنجاز تحدي اليوم 🎉 استريح، التحدي الجديد بينتظرك بكرة!',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('درجة النهاردة', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(
                              '${challenge.todayProgress?.scorePercentage.round() ?? 0}%',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: QatalyTheme.secondary),
                            ),
                          ],
                        ),
                        Container(width: 2, height: 36, color: Colors.white24),
                        Column(
                          children: [
                            const Text('تعديل الـ MMR', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 4),
                            Builder(builder: (context) {
                              final p = challenge.todayProgress;
                              final diff = (p?.newMmr ?? 0) - (p?.oldMmr ?? 0);
                              return Text(
                                '${diff >= 0 ? "+" : ""}$diff',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: diff >= 0 ? QatalyTheme.secondary : QatalyTheme.accent,
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, color: QatalyTheme.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'التحدي الجديد بعد ${_formatCountdown(_secondsUntilMidnight)} ⏳',
                        style: const TextStyle(color: QatalyTheme.primary, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'قطعة مخصصة لمستواك التنافسي الحالي يولّدها الذكاء الاصطناعي (6 أسئلة). اختبر فهمك للمفردات وعزز مهارات التفكير النقدي لديك!',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (challenge.isLoading)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: QatalyTheme.secondary),
                          SizedBox(height: 12),
                          Text(
                            'جاري تحضير القطعة والأسئلة لمستواك... ⏳',
                            style: TextStyle(color: QatalyTheme.secondary, fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  // ── Inline AI failure card: friendly message + retry + fallback ──
                  else if (challenge.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(color: QatalyTheme.accent, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_off, color: QatalyTheme.accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  challenge.errorMessage!,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BrutalistButton(
                            height: 42,
                            shadowOffset: 3,
                            backgroundColor: QatalyTheme.secondary,
                            onTap: () => _startDailyChallenge(student, challenge),
                            child: const Text('حاول مرة أخرى 🔄', style: TextStyle(color: Colors.black)),
                          ),
                          if (challenge.availablePassages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            BrutalistButton(
                              height: 42,
                              shadowOffset: 3,
                              backgroundColor: QatalyTheme.primary,
                              onTap: () => _startFallbackChallenge(student, challenge),
                              child: const Text('أو حُلّ قطعة جاهزة من المستر 📖', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]
                  else BrutalistButton(
                    backgroundColor: QatalyTheme.secondary,
                    onTap: () => _startDailyChallenge(student, challenge),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.black),
                        SizedBox(width: 8),
                        Text('ابدأ التحدي اليومي (6 أسئلة AI) 🥊', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Write & Correct (AI Journal)
          BrutalistCard(
            backgroundColor: QatalyTheme.cardBase,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📝 دفتر اليوميات الذكي (Write & Correct)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اكتب أي جملة أو موضوع تعبير بالإنجليزية، وسيقوم الـ AI بتصحيح القواعد فوراً لرفع الـ MMR.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                BrutalistInput(
                  controller: _journalController,
                  hintText: 'اكتب هنا مثلاً: "I goes to school yesterday"...',
                ),
                const SizedBox(height: 16),
                _isCorrectingJournal
                    ? const Center(child: CircularProgressIndicator(color: QatalyTheme.primary))
                    : BrutalistButton(
                        backgroundColor: QatalyTheme.primary,
                        onTap: _correctJournal,
                        child: const Text('صحح النص بالـ AI ✨', style: TextStyle(color: Colors.white)),
                      ),
                if (_journalResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📝 النص المصحح:', style: TextStyle(fontWeight: FontWeight.bold, color: QatalyTheme.secondary)),
                        Text(_journalResult!['corrected'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Divider(color: Colors.white24),
                        Text(_journalResult!['explanation'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الدرجة: ${_journalResult!['score']}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('+${_journalResult!['mmr_gain']} MMR 🏆', style: const TextStyle(fontWeight: FontWeight.bold, color: QatalyTheme.secondary)),
                          ],
                        )
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _explainVaultWord(String word) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: BrutalistCard(
          backgroundColor: QatalyTheme.cardBase,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📌 $word',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: QatalyTheme.secondary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                future: GeminiService.instance.translateWord(word),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: QatalyTheme.secondary),
                          SizedBox(height: 12),
                          Text(
                            'جاري تحليل الكلمة بالذكاء الاصطناعي... 🤖',
                            style: TextStyle(color: QatalyTheme.secondary, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'خطأ في جلب الشرح: ${snapshot.error}',
                      style: const TextStyle(color: QatalyTheme.accent),
                    );
                  }
                  return SingleChildScrollView(
                    child: Text(
                      snapshot.data ?? 'لا يوجد شرح متاح',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              BrutalistButton(
                backgroundColor: QatalyTheme.primary,
                onTap: () => Navigator.pop(context),
                child: const Text('تم الفهم 👍', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Sub-Tab 1: Weak Words Vault (Interactive AI Learning)
  // ─────────────────────────────────────────────────────────────
  Widget _buildVaultTab(Profile student, StatsProvider stats) {
    if (stats.isLoading && stats.weakWords.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: QatalyTheme.primary));
    }

    if (stats.weakWords.isEmpty) {
      return Center(
        child: RefreshIndicator(
          color: QatalyTheme.secondary,
          onRefresh: () => stats.loadWeakWords(student.id),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Text('📚', style: TextStyle(fontSize: 60), textAlign: TextAlign.center),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'قاموس الضعف فارغ وناصع!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'أنت على طريق التفوق! عندما تخطئ في أي كلمة داخل القطع، سيلتقطها الـ AI هنا فوراً لمساعدتك على إتقانها.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Client-side search + sort on top of the DB list (mistake_count desc).
    final query = _vaultSearchController.text.trim().toLowerCase();
    final items = stats.weakWords
        .where((w) => query.isEmpty || w.word.toLowerCase().contains(query))
        .toList();
    if (_vaultSortByNewest) {
      items.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    }

    return Column(
      children: [
        // Vault Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: BrutalistCard(
            backgroundColor: QatalyTheme.primary,
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قاموس ضعفك الذكي (${stats.weakWords.length} كلمة)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'اضغط «شرح AI» لفهم الكلمة، أو «أتقنتها» لشيلها من القاموس!',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search + sort controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              BrutalistInput(
                controller: _vaultSearchController,
                hintText: 'ابحث عن كلمة... 🔍',
                prefixIcon: Icons.search,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildVaultSortChip(
                      selected: !_vaultSortByNewest,
                      label: 'الأكثر خطأً 🔥',
                      onTap: () => setState(() => _vaultSortByNewest = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildVaultSortChip(
                      selected: _vaultSortByNewest,
                      label: 'الأحدث مشاهدة 🕐',
                      onTap: () => setState(() => _vaultSortByNewest = true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List of Weak Words
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'مفيش كلمة مطابقة للبحث 🤔',
                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                  ),
                )
              : RefreshIndicator(
                  color: QatalyTheme.secondary,
                  onRefresh: () => stats.loadWeakWords(student.id),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: BrutalistCard(
                          backgroundColor: QatalyTheme.cardBase,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            item.word,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w900,
                                              color: QatalyTheme.secondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'أخطأت فيها ${item.mistakeCount} مرات',
                                          style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  BrutalistButton(
                                    height: 36,
                                    backgroundColor: QatalyTheme.secondary,
                                    onTap: () => _explainVaultWord(item.word),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.auto_awesome, color: Colors.black, size: 14),
                                        SizedBox(width: 4),
                                        Text('شرح AI 🤖', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: BrutalistButton(
                                  height: 34,
                                  shadowOffset: 3,
                                  backgroundColor: const Color(0xFF15151A),
                                  onTap: () => _masterWord(student, stats, item),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.school, color: QatalyTheme.secondary, size: 14),
                                      SizedBox(width: 6),
                                      Text('أتقنتها، شيلها من القاموس ✅', style: TextStyle(color: QatalyTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildVaultSortChip({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? QatalyTheme.secondary : QatalyTheme.cardBase,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.black : Colors.white54,
          ),
        ),
      ),
    );
  }

  Future<void> _masterWord(Profile student, StatsProvider stats, VocabularyWeakness item) async {
    final removed = await stats.masterWeakWord(student.id, item.word);
    if (!mounted) return;
    if (removed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: QatalyTheme.accent,
          content: Text('تعذر حذف الكلمة، حاول مرة أخرى.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: QatalyTheme.secondary,
        content: Text(
          'أتقنتَ «${item.word}» 🎉',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        action: SnackBarAction(
          label: 'تراجع',
          textColor: Colors.black,
          onPressed: () => stats.restoreWeakWord(student.id, removed),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Sub-Tab 2: Leaderboard (Global Top 20 / Classroom toggle)
  // ─────────────────────────────────────────────────────────────
  Widget _buildGlobalLeaderboardTab(Profile currentStudent, StatsProvider stats) {
    final isClassMode = _leaderboardClassroomMode;

    if (stats.isLoading &&
        (isClassMode
            ? stats.classroomLeaderboard.isEmpty
            : stats.globalLeaderboard.isEmpty)) {
      return const Center(child: CircularProgressIndicator(color: QatalyTheme.secondary));
    }

    // No classroom joined → prompt to join from Settings instead of an empty list.
    if (isClassMode && (currentStudent.classroomId ?? '').isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎓', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text(
                'لسه مش راكب في فصل!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'ادخل كود السنتر من الإعدادات عشان تشوف صدارة فصلك وتتنافس مع زمايلك.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 20),
              BrutalistButton(
                backgroundColor: QatalyTheme.secondary,
                onTap: () => setState(() => _currentTab = 3),
                child: const Text('انضم لفصل من الإعدادات ⚙️', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );
    }

    final topList = isClassMode ? stats.classroomLeaderboard : stats.globalLeaderboard;

    if (topList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد طلاب مسجلون في الصدارة بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            BrutalistButton(
              backgroundColor: QatalyTheme.secondary,
              onTap: () => _refreshLeaderboard(currentStudent, stats),
              child: const Text('تحديث الصدارة 🔄', style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      );
    }

    final iAmInList = topList.any((p) => p.id == currentStudent.id);

    return RefreshIndicator(
      onRefresh: () => _refreshLeaderboard(currentStudent, stats),
      child: Column(
        children: [
          // ── Global / Classroom toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildVaultSortChip(
                    selected: !isClassMode,
                    label: 'عالمي 🌍',
                    onTap: () {
                      setState(() => _leaderboardClassroomMode = false);
                      stats.loadGlobalLeaderboard();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildVaultSortChip(
                    selected: isClassMode,
                    label: 'فصلي 🎓',
                    onTap: () {
                      setState(() => _leaderboardClassroomMode = true);
                      final classId = currentStudent.classroomId;
                      if ((classId ?? '').isNotEmpty) {
                        stats.loadClassroomData(classId!);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Banner
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: BrutalistCard(
              backgroundColor: QatalyTheme.primary,
              child: Row(
                children: [
                  Text(isClassMode ? '🎓' : '🥇', style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClassMode ? 'صدارة فصلك الحالية' : 'قائمة أفضل 20 طالب في مصر',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isClassMode
                              ? 'نافس زمايلك في الفصل وارفع الـ MMR عشان تتصدر!'
                              : 'تحدَّ الجميع وارفع الـ MMR الخاص بك لتتصدر القائمة العامة!',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Leaderboard List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topList.length + (!iAmInList ? 1 : 0),
              itemBuilder: (context, index) {
                // Last slot: the student's own rank footer (outside the top list).
                if (!iAmInList && index == topList.length) {
                  return _buildMyRankFooter(currentStudent, stats);
                }

                final item = topList[index];
                final rank = index + 1;
                final isMe = item.id == currentStudent.id;

                String rankBadge = '#$rank';
                Color badgeColor = Colors.black26;
                Color textColor = Colors.white;

                if (rank == 1) {
                  rankBadge = '🥇 #1';
                  badgeColor = const Color(0xFFFFD700); // Gold
                  textColor = Colors.black;
                } else if (rank == 2) {
                  rankBadge = '🥈 #2';
                  badgeColor = const Color(0xFFC0C0C0); // Silver
                  textColor = Colors.black;
                } else if (rank == 3) {
                  rankBadge = '🥉 #3';
                  badgeColor = const Color(0xFFCD7F32); // Bronze
                  textColor = Colors.white;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: BrutalistCard(
                    backgroundColor: isMe ? QatalyTheme.secondary : QatalyTheme.cardBase,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Rank Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.black : badgeColor,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Text(
                            rankBadge,
                            style: TextStyle(
                              color: isMe ? QatalyTheme.secondary : textColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Student Name & Tier
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.fullName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isMe ? Colors.black : Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMe)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'أنت',
                                        style: TextStyle(color: QatalyTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '${item.rank.toUpperCase()} • 🔥 ${item.dailyStreak} يوم',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe ? Colors.black87 : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // MMR Score
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.black : QatalyTheme.primary,
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Text(
                            '${item.mmr} MMR',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: isMe ? QatalyTheme.secondary : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshLeaderboard(Profile student, StatsProvider stats) async {
    if (_leaderboardClassroomMode) {
      final classId = student.classroomId;
      if ((classId ?? '').isNotEmpty) {
        await stats.loadClassroomData(classId!);
      }
    } else {
      await stats.loadGlobalLeaderboard();
    }
  }

  /// "Your rank" row shown at the bottom when the student is outside the
  /// visible top list (global mode).
  Widget _buildMyRankFooter(Profile currentStudent, StatsProvider stats) {
    if (stats.myGlobalRank == null) {
      stats.loadMyGlobalRank(currentStudent.mmr); // async fill-in
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      child: BrutalistCard(
        backgroundColor: QatalyTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ترتيبك العالمي: #${stats.myGlobalRank}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Text(
                '${currentStudent.mmr} MMR',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: QatalyTheme.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Sub-Tab 3: Settings Tab
  // ─────────────────────────────────────────────────────────────
  Widget _buildSettingsTab(Profile student, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Profile Card
          BrutalistCard(
            backgroundColor: QatalyTheme.cardBase,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: QatalyTheme.secondary,
                      child: Icon(Icons.person, size: 36, color: Colors.black),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.isPremium ? '👑 عضوية بريميوم نشطة' : '💎 حساب مجاني أساسي',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: student.isPremium ? QatalyTheme.secondary : Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الرتبة التنافسية: ${student.rank.toUpperCase()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('النقاط: ${student.mmr} MMR', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: QatalyTheme.secondary)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 1: Link Classroom Code
          BrutalistCard(
            backgroundColor: QatalyTheme.cardBase,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏫 الربط بسنتر المعلم:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'أدخل كود المعلم الخاص بسنترك (مثل ALI2026 أو HASSAN88) للربط بالحساب.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                BrutalistInput(
                  controller: _classCodeController,
                  hintText: 'كود السنتر (مثل: ALI2026)',
                ),
                const SizedBox(height: 12),
                BrutalistButton(
                  backgroundColor: QatalyTheme.secondary,
                  onTap: _joinClassroom,
                  child: const Text('تفعيل كود السنتر 🔗', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Activate VIP Code
          BrutalistCard(
            backgroundColor: QatalyTheme.cardBase,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎫 تفعيل كود الوصول التعليمي:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'أدخل كود التفعيل المقدم من معلمك أو سنترك التعليمي:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                BrutalistInput(
                  controller: _codeController,
                  hintText: 'كود التفعيل (مثل: EDU-2026)',
                ),
                const SizedBox(height: 12),
                BrutalistButton(
                  backgroundColor: QatalyTheme.primary,
                  onTap: _claimCode,
                  child: const Text('تفعيل الكود ⚡', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: Teacher Control Panel Switch
          BrutalistButton(
            backgroundColor: QatalyTheme.cardBase,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherDashboard()),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dashboard_customize, color: QatalyTheme.secondary),
                SizedBox(width: 8),
                Text(
                  'فتح لوحة تحكم المعلم (إنشاء قطع بالـ AI) 📊',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: Legal, Privacy & Licenses
          BrutalistButton(
            backgroundColor: const Color(0xFF1E293B),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalScreen()),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.privacy_tip_outlined, color: QatalyTheme.secondary),
                SizedBox(width: 8),
                Text(
                  'الشروط والخصوصية وتراخيص التطبيق 🛡️',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Section 5: Logout Button
          BrutalistButton(
            backgroundColor: QatalyTheme.accent,
            onTap: () => auth.signOut(),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.white),
                SizedBox(width: 8),
                Text('تسجيل الخروج 🚪', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // App Info
          const Center(
            child: Text(
              'قطعلي (Qata\'ly) v2.5 — منصة تدريب الانجليزي بالذكاء الاصطناعي',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
