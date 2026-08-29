import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/widgets/brutalist_widgets.dart';

/// First-run onboarding explaining the gamified concepts (daily challenge,
/// MMR, ranks, streak, weak-words dictionary, VIP). Shown once, then the
/// `onboarding_completed` SharedPreferences flag suppresses it forever.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String _flagKey = 'onboarding_completed';

  /// True when the intro has never been shown on this device.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_flagKey) ?? false);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    (
      emoji: '⚡',
      title: 'التحدي اليومي والـ MMR',
      body: 'كل يوم الذكاء الاصطناعي بيولّدلك قطعة قراءة بـ 6 أسئلة على قد مستواك. '
          'الـ MMR هي نقاطك التنافسية: تحل صح أكتر، تاخد نقاط أكتر، والقطعات تبقى أصعب شوية.',
      color: QatalyTheme.secondary,
    ),
    (
      emoji: '🏅',
      title: 'الرتب والسلسلة 🔥',
      body: 'اصعد من Bronze لحد Diamond II Master مع كل تحسن. '
          'وحل كل يوم من غير انقطاع عشان سلسلة الأيام (الستريك) تفضل بتطول وتثبت مستواك.',
      color: QatalyTheme.primary,
    ),
    (
      emoji: '📖',
      title: 'قاموس ضعفك والترجمة السحرية',
      body: 'جوه التحدي، اضغط ضغطتين على أي كلمة مش فاهمها والـ AI هيترجمهالك فورًا. '
          'والكلمات اللي بتغلط فيها بتتجمعلك في «قاموس الضعف» مع شرح خاص عشان تتقنها.',
      color: QatalyTheme.accent,
    ),
    (
      emoji: '👑',
      title: 'عضوية VIP',
      body: 'عندك كود تفعيل؟ ادخله من الإعدادات عشان تفتح مزايا البريميوم. '
          'الكود بييجي من السنتر أو المعلم بتاعك.',
      color: QatalyTheme.secondary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen._flagKey, true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    final slide = _slides[_currentPage];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: QatalyTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: GestureDetector(
                    onTap: _finish,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'تخطي ⏭',
                        style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      final s = _slides[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: QatalyTheme.cardBase,
                                border: Border.all(color: Colors.black, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
                                ],
                              ),
                              child: Center(child: Text(s.emoji, style: const TextStyle(fontSize: 56))),
                            ),
                          ),
                          const SizedBox(height: 36),
                          BrutalistCard(
                            backgroundColor: QatalyTheme.cardBase,
                            child: Column(
                              children: [
                                Text(
                                  s.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  s.body,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.6),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Progress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Container(
                        width: i == _currentPage ? 22 : 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i == _currentPage ? slide.color : Colors.white24,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                BrutalistButton(
                  backgroundColor: slide.color,
                  height: 52,
                  onTap: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    isLast ? 'يلا نبدأ 🚀' : 'التالي ➡',
                    style: TextStyle(
                      color: slide.color == QatalyTheme.primary ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
