import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qataly/models/passage.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/state/challenge_provider.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/widgets/brutalist_widgets.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with TickerProviderStateMixin {
  // Tab controller for switching between Passage and Questions
  late TabController _tabController;

  // Shake animation controller for wrong answers
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Selection states
  bool _challengeSubmitted = false;
  final Map<int, bool> _showExplanations = {}; // questionIndex -> true/false

  // Select-then-confirm: a tap only "selects"; the confirm button locks it.
  final Map<int, String> _pendingSelection = {}; // questionId -> letter
  final Set<int> _confirmedQuestions = {};

  // First-run coach mark for the double-tap translation feature
  bool _showTranslateHint = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    SharedPreferences.getInstance().then((prefs) {
      final seen = prefs.getBool('hint_words_translate_seen') ?? false;
      if (mounted && !seen) {
        setState(() => _showTranslateHint = true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  Future<void> _dismissTranslateHint() async {
    setState(() => _showTranslateHint = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hint_words_translate_seen', true);
  }

  // Double tap handler using AI translation
  void _showWordTranslation(String rawWord, ChallengeProvider provider) {
    final word = rawWord.replaceAll(RegExp(r'[^\w\-]'), '');
    if (word.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: BrutalistCard(
            backgroundColor: QatalyTheme.cardBase,
            shadowColor: QatalyTheme.primary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ترجمة المستر 💡',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: QatalyTheme.secondary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: provider.translateWordWithAI(word),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Column(
                          children: [
                            CircularProgressIndicator(
                                color: QatalyTheme.secondary),
                            SizedBox(height: 12),
                            Text(
                              'جاري الترجمة بالذكاء الاصطناعي...',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }
                    final translation =
                        snapshot.data ?? 'تعذر الحصول على الترجمة';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: Text(
                        translation,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                BrutalistButton(
                  height: 44,
                  backgroundColor: QatalyTheme.secondary,
                  onTap: () => Navigator.pop(context),
                  child: const Text('فهمت الكلمة 👍',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportPassageDialog(String passageId) {
    String selectedReason = 'محتوى غير لائق أو مسيء';
    final customNotesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final reasons = [
            'محتوى غير لائق أو مسيء',
            'معلومات غير دقيقة أو خطأ لغوي جسيم',
            'محتوى غير مناسب للمرحلة الدراسية',
            'مشكلة في صياغة الأسئلة أو الإجابات',
            'سبب آخر',
          ];

          return AlertDialog(
            backgroundColor: const Color(0xFF131B3E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: QatalyTheme.accent, width: 2),
            ),
            title: const Row(
              children: [
                Icon(Icons.flag_outlined, color: QatalyTheme.accent, size: 24),
                SizedBox(width: 8),
                Text(
                  'إبلاغ عن محتوى القطعة',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'نحرص على سلامة وجودة المحتوى المولد بالذكاء الاصطناعي. حدد سبب البلاغ:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) {
                    final isSelected = reason == selectedReason;
                    return InkWell(
                      onTap: () =>
                          setDialogState(() => selectedReason = reason),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? QatalyTheme.accent.withValues(alpha: 0.2)
                              : Colors.black26,
                          border: Border.all(
                            color: isSelected
                                ? QatalyTheme.accent
                                : Colors.white12,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? QatalyTheme.accent
                                  : Colors.white54,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customNotesController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ملاحظات إضافية (اختياري)...',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: QatalyTheme.accent),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: QatalyTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(
                        'شكراً لك! تم استلام بلاغك وسيتم مراجعة المحتوى والتحقق منه فوراً.',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
                child: const Text('إرسال البلاغ',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Quick peek bottom sheet so students can check the passage without switching tabs
  void _showPassagePeekBottomSheet(Passage passage, ChallengeProvider challenge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF131B3E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: QatalyTheme.secondary, width: 3),
                  left: BorderSide(color: Colors.black, width: 2),
                  right: BorderSide(color: Colors.black, width: 2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.menu_book,
                              color: QatalyTheme.secondary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'نص القطعة للمراجعة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 16),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '💡 انقر مرتين على أي كلمة بالإنجليزية لترجمتها فورياً:',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildInteractivePassage(
                          passage.passageText, challenge),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final challenge = Provider.of<ChallengeProvider>(context);
    final passage = challenge.currentPassage;

    if (passage == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'تعذر تحميل التحدي',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'حدث خطأ أثناء تحضير القطعة. ارجع للصفحة الرئيسية وابدأ التحدي مرة أخرى.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                BrutalistButton(
                  backgroundColor: QatalyTheme.secondary,
                  onTap: () => Navigator.pop(context),
                  child: const Text('العودة للرئيسية',
                      style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_challengeSubmitted) {
      return PopScope(
        canPop: false,
        child: _buildResultsScreen(challenge, auth.currentUser?.fullName ?? 'بطل قطعلي'),
      );
    }

    final confirmedCount = passage.questions
        .where((q) => _confirmedQuestions.contains(q.id))
        .length;

    // Detect wide screens / tablets (e.g. tablet, landscape, or desktop)
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 720;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'تحدي المستوى: ${passage.difficultyLevel}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                challenge.reset();
                Navigator.pop(context);
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: Colors.white70),
                tooltip: 'إبلاغ عن محتوى القطعة',
                onPressed: () => _showReportPassageDialog(passage.id),
              ),
            ],
            bottom: isWideScreen
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B3E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: QatalyTheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 13),
                        tabs: [
                          const Tab(
                            iconMargin: EdgeInsets.zero,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.menu_book, size: 16),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '📖 القطعة',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            iconMargin: EdgeInsets.zero,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.help_outline, size: 16),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '❓ الأسئلة ($confirmedCount/${passage.questions.length})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          body: SafeArea(
            child: isWideScreen
                ? _buildWideScreenLayout(passage, challenge, confirmedCount)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Passage view
                      _buildPassageTab(passage, challenge),
                      // TAB 2: Questions view
                      _buildQuestionsTab(passage, challenge, confirmedCount),
                    ],
                  ),
          ),
        );
      },
    );
  }

  /// Wide Screen (Tablet / Desktop / Landscape) dual-pane side-by-side view
  Widget _buildWideScreenLayout(
      Passage passage, ChallengeProvider challenge, int confirmedCount) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Pane: Passage
          Expanded(
            flex: 5,
            child: _buildPassageCard(passage, challenge, isWide: true),
          ),
          const SizedBox(width: 16),
          // Right Pane: Question
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              child: _buildQuestionCard(passage, challenge, confirmedCount,
                  isWide: true),
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile Tab 1: Full-height comfortable passage reading with double-tap AI translation
  Widget _buildPassageTab(Passage passage, ChallengeProvider challenge) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildPassageCard(passage, challenge, isWide: false),
          ),
          const SizedBox(height: 12),
          BrutalistButton(
            height: 48,
            backgroundColor: QatalyTheme.secondary,
            onTap: () {
              _tabController.animateTo(1);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'الانتقال للأسئلة الآن 🚀',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.black, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile Tab 2: Full-height, comfortable, non-cramped question & options solving view
  Widget _buildQuestionsTab(
      Passage passage, ChallengeProvider challenge, int confirmedCount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick "Peek Passage" button banner
          InkWell(
            onTap: () => _showPassagePeekBottomSheet(passage, challenge),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: QatalyTheme.secondary, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: QatalyTheme.secondary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مراجعة سريعة للقطعة (مع ترجمة الكلمات) 🔍',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Main Question Card with full vertical space
          _buildQuestionCard(passage, challenge, confirmedCount, isWide: false),
        ],
      ),
    );
  }

  /// Passage Card with coach mark and double-tap interactive words
  Widget _buildPassageCard(Passage passage, ChallengeProvider challenge,
      {required bool isWide}) {
    return BrutalistCard(
      backgroundColor: QatalyTheme.cardBase,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // First-run coach mark for double-tap translation
          if (_showTranslateHint) ...[
            BrutalistCard(
              backgroundColor: QatalyTheme.primary,
              padding: const EdgeInsets.all(10),
              shadowOffset: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.touch_app, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تلميح: انقر مرتين على أي كلمة في القطعة وسيترجمها لك الذكاء الاصطناعي فورًا!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BrutalistButton(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: QatalyTheme.secondary,
                    shadowOffset: 2,
                    onTap: _dismissTranslateHint,
                    child: const Text('تمام، فهمت 👌',
                        style: TextStyle(color: Colors.black, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: QatalyTheme.secondary),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'اقرأ القطعة بتركيز (انقر مرتين على أي كلمة لترجمتها):',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: _buildInteractivePassage(
                  passage.passageText, challenge),
            ),
          ),
        ],
      ),
    );
  }

  /// Question Card with ample space for question text, options, and explanations
  Widget _buildQuestionCard(
      Passage passage, ChallengeProvider challenge, int confirmedCount,
      {required bool isWide}) {
    final currentQuestion = passage.questions[challenge.currentQuestionIndex];
    final confirmedOption = challenge.selectedAnswers[currentQuestion.id];
    final pendingOption = _pendingSelection[currentQuestion.id];
    final isConfirmed = _confirmedQuestions.contains(currentQuestion.id);

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
              _shakeAnimation.value * sin(10 * pi * _shakeController.value), 0),
          child: child,
        );
      },
      child: BrutalistCard(
        backgroundColor: const Color(0xFF15151A),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Progress bar + answered counter ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'أجبت $confirmedCount من ${passage.questions.length}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: QatalyTheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'سؤال ${challenge.currentQuestionIndex + 1} من ${passage.questions.length}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
                color: Colors.black26,
              ),
              child: LinearProgressIndicator(
                value: passage.questions.isEmpty
                    ? 0
                    : confirmedCount / passage.questions.length,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    QatalyTheme.secondary),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),

            // ── Question dots (tap to jump) ──
            SizedBox(
              height: 24,
              child: Row(
                children: [
                  for (var i = 0; i < passage.questions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _buildQuestionDot(
                        challenge, passage.questions[i].id, i),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Navigation Bar (Prev / Next) + instructions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'اختر إجابتك ثم اضغط «تأكيد»:',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white60),
                  ),
                ),
                Row(
                  children: [
                    if (challenge.currentQuestionIndex > 0)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_back_ios,
                            size: 16, color: Colors.white70),
                        tooltip: 'السؤال السابق',
                        onPressed: () => challenge.prevQuestion(),
                      ),
                    if (challenge.currentQuestionIndex <
                        passage.questions.length - 1)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.white70),
                        tooltip: 'السؤال التالي',
                        onPressed: () => challenge.nextQuestion(),
                      ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 6),

            // Question Text (Readable, responsive, high contrast)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  currentQuestion.questionText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Options List (Spacious, easy tap targets)
            ...currentQuestion.options.entries.map((opt) {
              final letter = opt.key;
              final optionText = opt.value;
              final isSelected = confirmedOption == letter;
              final isPending = !isConfirmed && pendingOption == letter;
              final isCorrect = letter == currentQuestion.correctOption;

              Color cardColor = const Color(0xFF1E1E28);
              Color textColor = Colors.white;

              if (isConfirmed && isSelected) {
                if (isCorrect) {
                  cardColor = QatalyTheme.secondary;
                  textColor = Colors.black;
                } else {
                  cardColor = QatalyTheme.accent;
                  textColor = Colors.white;
                }
              } else if (isPending) {
                cardColor = QatalyTheme.primary;
                textColor = Colors.white;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: BrutalistCard(
                  backgroundColor: cardColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shadowOffset: 3,
                  onTap: () {
                    if (isConfirmed) return;
                    setState(() {
                      _pendingSelection[currentQuestion.id] = letter;
                    });
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black,
                        radius: 14,
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: (isSelected || isPending)
                                ? cardColor
                                : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            optionText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                      if (isConfirmed && isSelected)
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.error,
                          color: isCorrect ? Colors.black : Colors.white,
                          size: 20,
                        )
                      else if (isPending)
                        const Icon(Icons.radio_button_checked,
                            color: Colors.white, size: 20),
                    ],
                  ),
                ),
              );
            }),

            // ── Confirm button (locks the selected answer) ──
            if (!isConfirmed && pendingOption != null) ...[
              const SizedBox(height: 6),
              BrutalistButton(
                height: 48,
                shadowOffset: 3,
                backgroundColor: QatalyTheme.primary,
                onTap: () {
                  challenge.selectOption(currentQuestion.id, pendingOption);
                  setState(() => _confirmedQuestions.add(currentQuestion.id));
                  if (pendingOption != currentQuestion.correctOption) {
                    _triggerShake();
                    setState(() {
                      _showExplanations[challenge.currentQuestionIndex] = true;
                    });
                  }
                },
                child: const Text('تأكيد الإجابة ✅',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ],

            // Master explanation dropdown
            if (_showExplanations[challenge.currentQuestionIndex] == true) ...[
              const SizedBox(height: 12),
              BrutalistCard(
                backgroundColor: const Color(0xFF2E2E3A),
                padding: const EdgeInsets.all(14),
                shadowOffset: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb,
                            size: 18, color: QatalyTheme.secondary),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text('تفسير المستر بالعامية 💡',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: QatalyTheme.secondary,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentQuestion.explanation,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70, height: 1.45),
                    ),
                  ],
                ),
              )
            ],

            // Submit Challenge button
            if (challenge.selectedAnswers.length == passage.questions.length &&
                !_challengeSubmitted) ...[
              const SizedBox(height: 14),
              challenge.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : BrutalistButton(
                      height: 50,
                      backgroundColor: QatalyTheme.secondary,
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final res = await challenge.submitChallenge(auth.currentUser!.id);
                        if (res != null) {
                          setState(() {
                            _challengeSubmitted = true;
                          });
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: QatalyTheme.accent,
                              content: Text(
                                challenge.errorMessage ??
                                    'حدث خطأ أثناء تسليم الإجابة. حاول مرة أخرى.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('تسجيل وإرسال إجابة التحدي 🏆',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                    ),
            ]
          ],
        ),
      ),
    );
  }

  /// Small square dot per question: lime = confirmed, violet = selected but
  /// not confirmed yet, dark = unanswered. Tap to jump to that question.
  Widget _buildQuestionDot(
      ChallengeProvider challenge, int questionId, int index) {
    final isCurrent = challenge.currentQuestionIndex == index;
    final confirmed = _confirmedQuestions.contains(questionId);
    final hasPending = _pendingSelection[questionId] != null;

    final Color color;
    if (confirmed) {
      color = QatalyTheme.secondary;
    } else if (hasPending) {
      color = QatalyTheme.primary;
    } else {
      color = Colors.white24;
    }

    return GestureDetector(
      onTap: () => challenge.goToQuestion(index),
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isCurrent ? Colors.white : Colors.black,
            width: 2,
          ),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: confirmed ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  // Splitting text and building Wrap of words
  Widget _buildInteractivePassage(
      String passageText, ChallengeProvider provider) {
    final paragraphs = passageText.split('\n');

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((paragraph) {
          if (paragraph.trim().isEmpty) return const SizedBox(height: 12);

          final words = paragraph.split(' ');

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Wrap(
              spacing: 5.0,
              runSpacing: 5.0,
              children: words.map((word) {
                return GestureDetector(
                  onDoubleTap: () => _showWordTranslation(word, provider),
                  child: Text(
                    word,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                      decorationColor: Colors.white38,
                      decorationThickness: 1.2,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Result screen (full-screen swap; system-back is blocked via PopScope)
  Widget _buildResultsScreen(ChallengeProvider challenge, String studentName) {
    final result = challenge.lastProgressResult;
    if (result == null) {
      return const Scaffold(
          body: Center(child: Text("خطأ في جلب نتيجة التقدم!")));
    }

    final diff = result.newMmr - result.oldMmr;
    final isGain = diff >= 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 72)),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'أحسنت يا $studentName!',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),

                  BrutalistCard(
                    backgroundColor: QatalyTheme.cardBase,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          isGain ? '+$diff MMR ⚡' : '$diff MMR 📉',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: isGain
                                ? QatalyTheme.secondary
                                : QatalyTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'المستوى الجديد: ${result.newMmr}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70),
                        ),
                        const Divider(color: Colors.white24, height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('دقة الإجابة',
                                '${(result.scorePercentage * 100).toInt()}% 🎯'),
                            _buildStatColumn('المستوى السابق', '${result.oldMmr}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  BrutalistButton(
                    height: 48,
                    backgroundColor: QatalyTheme.secondary,
                    onTap: () {
                      challenge.reset();
                      Navigator.pop(context);
                    },
                    child: const Text('العودة للرئيسية 🏠',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
      ],
    );
  }
}
