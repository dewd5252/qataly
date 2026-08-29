import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/state/challenge_provider.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/widgets/brutalist_widgets.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> with SingleTickerProviderStateMixin {
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

  // Double tap handler using Gemini AI
  void _showWordTranslation(String rawWord, ChallengeProvider provider) {
    // Strip punctuation
    final word = rawWord.replaceAll(RegExp(r'[^\w\-]'), '');
    if (word.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                      'ترجمة المستر (Gemini AI 🤖)',
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
                            CircularProgressIndicator(color: QatalyTheme.secondary),
                            SizedBox(height: 12),
                            Text(
                              'جاري الترجمة بالذكاء الاصطناعي...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }
                    final translation = snapshot.data ?? 'تعذر الحصول على الترجمة';
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
                  height: 40,
                  backgroundColor: QatalyTheme.secondary,
                  onTap: () => Navigator.pop(context),
                  child: const Text('فهمت الكلمة 👍', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
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
                  child: const Text('العودة للرئيسية', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_challengeSubmitted) {
      // Full-screen results: block system-back so the student cannot return
      // to the already-answered questions.
      return PopScope(
        canPop: false,
        child: _buildResultsScreen(challenge, auth.currentUser!.fullName),
      );
    }

    final currentQuestion = passage.questions[challenge.currentQuestionIndex];
    final confirmedOption = challenge.selectedAnswers[currentQuestion.id];
    final pendingOption = _pendingSelection[currentQuestion.id];
    final isConfirmed = _confirmedQuestions.contains(currentQuestion.id);

    final confirmedCount = passage.questions
        .where((q) => _confirmedQuestions.contains(q.id))
        .length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'تحدي صعوبة مستوى: ${passage.difficultyLevel}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            challenge.reset();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // TOP HALF: Passage Text scrollbox
            Expanded(
              flex: 11,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: BrutalistCard(
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
                                      'تلميح: اضغط ضغطتين على أي كلمة في القطعة وسيترجمها لك الذكاء الاصطناعي فورًا!',
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
                                child: const Text('تمام، فهمت 👌', style: TextStyle(color: Colors.black, fontSize: 12)),
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
                          Text(
                            'اقرأ القطعة بتركيز (انقر مرتين على أي كلمة لترجمتها):',
                            style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildInteractivePassage(passage.passageText, challenge),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BOTTOM HALF: Question Panel
            Expanded(
              flex: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value * sin(10 * pi * _shakeController.value), 0),
                      child: child,
                    );
                  },
                  child: BrutalistCard(
                    backgroundColor: const Color(0xFF15151A),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Brutalist progress bar + answered counter ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'أجبت $confirmedCount من ${passage.questions.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: QatalyTheme.secondary,
                              ),
                            ),
                            Text(
                              'سؤال ${challenge.currentQuestionIndex + 1} من ${passage.questions.length}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 2),
                            color: Colors.black26,
                          ),
                          child: LinearProgressIndicator(
                            value: passage.questions.isEmpty
                                ? 0
                                : confirmedCount / passage.questions.length,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(QatalyTheme.secondary),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Question dots (tap to jump) ──
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: [
                              for (var i = 0; i < passage.questions.length; i++) ...[
                                if (i > 0) const SizedBox(width: 6),
                                _buildQuestionDot(challenge, passage.questions[i].id, i),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Question Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'اختر إجابتك ثم اضغط «تأكيد»:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white54),
                            ),
                            Row(
                              children: [
                                if (challenge.currentQuestionIndex > 0)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.white70),
                                    onPressed: () => challenge.prevQuestion(),
                                  ),
                                if (challenge.currentQuestionIndex < passage.questions.length - 1)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                                    onPressed: () => challenge.nextQuestion(),
                                  ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentQuestion.questionText,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 12),

                        // Options wrap
                        Expanded(
                          child: ListView(
                            shrinkWrap: true,
                            children: currentQuestion.options.entries.map((opt) {
                              final letter = opt.key;
                              final optionText = opt.value;
                              final isSelected = confirmedOption == letter;
                              final isPending = !isConfirmed && pendingOption == letter;
                              final isCorrect = letter == currentQuestion.correctOption;

                              Color cardColor = QatalyTheme.cardBase;

                              if (isConfirmed && isSelected) {
                                if (isCorrect) {
                                  cardColor = QatalyTheme.secondary;
                                } else {
                                  cardColor = QatalyTheme.accent;
                                }
                              } else if (isPending) {
                                cardColor = QatalyTheme.primary;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: BrutalistCard(
                                  backgroundColor: cardColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shadowOffset: 3,
                                  onTap: () {
                                    // Confirmed answers are locked; a plain tap
                                    // only selects and waits for confirmation.
                                    if (isConfirmed) return;
                                    setState(() {
                                      _pendingSelection[currentQuestion.id] = letter;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.black,
                                        radius: 12,
                                        child: Text(
                                          letter,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: (isSelected || isPending) ? cardColor : Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          optionText,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isConfirmed && isSelected && isCorrect ? Colors.black : Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (isConfirmed && isSelected)
                                        Icon(
                                          isCorrect ? Icons.check_circle : Icons.error,
                                          color: isCorrect ? Colors.black : Colors.white,
                                          size: 18,
                                        )
                                      else if (isPending)
                                        const Icon(Icons.radio_button_checked, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ── Confirm button (locks the selected answer) ──
                        if (!isConfirmed && pendingOption != null) ...[
                          const SizedBox(height: 4),
                          BrutalistButton(
                            height: 42,
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
                            child: const Text('تأكيد الإجابة ✅', style: TextStyle(color: Colors.white)),
                          ),
                        ],

                        // Master explanation dropdown
                        if (_showExplanations[challenge.currentQuestionIndex] == true) ...[
                          const SizedBox(height: 10),
                          BrutalistCard(
                            backgroundColor: const Color(0xFF2E2E3A),
                            padding: const EdgeInsets.all(12),
                            shadowOffset: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lightbulb, size: 16, color: QatalyTheme.secondary),
                                    SizedBox(width: 6),
                                    Text('تفسير المستر جي بي تي بالعامية 💡', style: TextStyle(fontWeight: FontWeight.bold, color: QatalyTheme.secondary, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentQuestion.explanation,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                                ),
                              ],
                            ),
                          )
                        ],

                        // Submit Challenge button
                        if (challenge.selectedAnswers.length == passage.questions.length && !_challengeSubmitted) ...[
                          const SizedBox(height: 12),
                          challenge.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : BrutalistButton(
                                  backgroundColor: QatalyTheme.secondary,
                                  onTap: () async {
                                    final messenger = ScaffoldMessenger.of(context);
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
                                  child: const Text('تسجيل وإرسال إجابة التحدي 🏆', style: TextStyle(color: Colors.black)),
                                ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Small square dot per question: lime = confirmed, violet = selected but
  /// not confirmed yet, dark = unanswered. Tap to jump to that question.
  Widget _buildQuestionDot(ChallengeProvider challenge, int questionId, int index) {
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
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isCurrent ? Colors.white : Colors.black,
            width: 2,
          ),
        ),
      ),
    );
  }

  // Splitting text and building Wrap of words
  Widget _buildInteractivePassage(String passageText, ChallengeProvider provider) {
    // Split into paragraphs by newline
    final paragraphs = passageText.split('\n');

    // The passage is English — force LTR so the layout stays correct under a
    // future RTL app locale.
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
              runSpacing: 4.0,
              children: words.map((word) {
                return GestureDetector(
                  onDoubleTap: () => _showWordTranslation(word, provider),
                  child: Text(
                    word,
                    // Dotted underline signals the word is tappable.
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
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
    if (result == null) return const Scaffold(body: Center(child: Text("خطأ في جلب نتيجة التقدم!")));

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
                  // Celebration Shield
                  const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 80)),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'أحسنت يا $studentName!',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),

                  BrutalistCard(
                    backgroundColor: QatalyTheme.cardBase,
                    child: Column(
                      children: [
                        const Text(
                          'نتائج تحدي اليوم:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: QatalyTheme.secondary),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('درجة الحل', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('${result.scorePercentage.round()}%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            Container(width: 2, height: 40, color: Colors.white24),
                            Column(
                              children: [
                                const Text('تعديل الـ MMR', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  '${isGain ? "+" : ""}$diff',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: isGain ? QatalyTheme.secondary : QatalyTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Text(
                          'مستواك اللغوي الجديد: ${result.newMmr} MMR',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Return Home
                  BrutalistButton(
                    backgroundColor: QatalyTheme.secondary,
                    onTap: () {
                      challenge.reset();
                      // Refresh profile
                      Provider.of<AuthProvider>(context, listen: false).refreshProfile();
                      Navigator.pop(context);
                    },
                    child: const Text('العودة للساحة الرئيسية 🛡️', style: TextStyle(color: Colors.black)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
