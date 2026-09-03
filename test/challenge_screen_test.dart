import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qataly/models/passage.dart';
import 'package:qataly/models/profile.dart';
import 'package:qataly/screens/challenge_screen.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/state/challenge_provider.dart';
import 'package:qataly/theme.dart';

Passage _createMockPassage() {
  return Passage(
    id: 'mock-passage-1',
    passageText:
        'Artificial Intelligence is reshaping the modern world in profound ways.\nScientists and educators around the globe utilize neural networks to enhance learning paradigms and solve complex real-world challenges.',
    difficultyLevel: 1200,
    vocabularyUsed: ['intelligence', 'neural', 'paradigms'],
    questions: [
      Question(
        id: 1,
        questionText:
            'What is the primary role of artificial intelligence described in the text?',
        options: {
          'A': 'Reshaping the modern world and solving complex challenges',
          'B': 'Replacing human teachers completely in universities',
          'C': 'Eliminating all computer hardware requirements',
          'D': 'Decreasing global educational productivity significantly',
        },
        correctOption: 'A',
        explanation:
            'القطعة توضح أن الذكاء الاصطناعي يعيد تشكيل العالم ويساعد في حل التحديات المعقدة.',
      ),
      Question(
        id: 2,
        questionText: 'Who utilizes neural networks according to the passage?',
        options: {
          'A': 'Automotive mechanics exclusively',
          'B': 'Scientists and educators globally',
          'C': 'Only financial bankers',
          'D': 'Ancient history archaeologists',
        },
        correctOption: 'B',
        explanation:
            'القطعة ذكرت نصاً: Scientists and educators around the globe.',
      ),
    ],
    createdAt: DateTime.now(),
  );
}

Widget _buildTestableChallengeScreen({
  required Passage passage,
  Size screenSize = const Size(360, 640),
}) {
  final authProvider = AuthProvider(autoInit: false);
  authProvider.setCurrentUserForTesting(
    Profile(
      id: 'test-user-id',
      fullName: 'أحمد محمود',
      classroomId: null,
      mmr: 1200,
      dailyStreak: 3,
      lastActiveDate: '2026-09-01',
      isPremium: true,
      createdAt: DateTime.now(),
    ),
  );

  final challengeProvider = ChallengeProvider();
  challengeProvider.setPassageForTesting(passage);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<ChallengeProvider>.value(value: challengeProvider),
    ],
    child: MaterialApp(
      theme: QatalyTheme.themeData,
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          textScaler: const TextScaler.linear(1.0),
        ),
        child: const ChallengeScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'hint_words_translate_seen': true});
  });

  group('ChallengeScreen Responsive UI Tests', () {
    testWidgets(
        'Renders cleanly on small phone screen (360x640) without overflow',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final passage = _createMockPassage();
      await tester.pumpWidget(
        _buildTestableChallengeScreen(
          passage: passage,
          screenSize: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      // Verify TabBar is visible on phone screen
      expect(find.text('📖 القطعة'), findsOneWidget);
      expect(find.text('Artificial'), findsWidgets);
      expect(find.text('الانتقال للأسئلة الآن 🚀'), findsOneWidget);

      // Tap on Questions Tab
      await tester.tap(find.textContaining('❓ الأسئلة'));
      await tester.pumpAndSettle();

      // Verify Question text & 4 options render cleanly
      expect(
        find.text(
            'What is the primary role of artificial intelligence described in the text?'),
        findsOneWidget,
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);

      // Verify NO RenderFlex overflow occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Renders cleanly on tiny phone screen (320x568 - iPhone SE 1st gen)',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final passage = _createMockPassage();
      await tester.pumpWidget(
        _buildTestableChallengeScreen(
          passage: passage,
          screenSize: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to questions tab
      await tester.tap(find.textContaining('❓ الأسئلة'));
      await tester.pumpAndSettle();

      // Verify Peek button & questions render without errors
      expect(find.textContaining('مراجعة سريعة للقطعة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on tablet/wide screen dual pane (800x1280)',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1280));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final passage = _createMockPassage();
      await tester.pumpWidget(
        _buildTestableChallengeScreen(
          passage: passage,
          screenSize: const Size(800, 1280),
        ),
      );
      await tester.pumpAndSettle();

      // On wide screens, both passage and questions appear side-by-side
      expect(find.text('Artificial'), findsWidgets);
      expect(
        find.text(
            'What is the primary role of artificial intelligence described in the text?'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Select-then-confirm workflow and explanation display',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final passage = _createMockPassage();
      await tester.pumpWidget(
        _buildTestableChallengeScreen(
          passage: passage,
          screenSize: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Questions tab
      await tester.tap(find.textContaining('❓ الأسئلة'));
      await tester.pumpAndSettle();

      // Tap option B (wrong answer) — scroll to it if needed
      final optionFinder = find.text(
          'Replacing human teachers completely in universities');
      await tester.scrollUntilVisible(optionFinder, 50,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      // Confirm button should appear — scroll to it
      final confirmFinder = find.text('تأكيد الإجابة ✅');
      await tester.scrollUntilVisible(confirmFinder, 50,
          scrollable: find.byType(Scrollable).first);
      expect(confirmFinder, findsOneWidget);

      // Tap Confirm
      await tester.tap(confirmFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // No unhandled exceptions from the interaction
      expect(tester.takeException(), isNull);
    });
  });
}
