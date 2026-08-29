import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/widgets/brutalist_widgets.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/state/challenge_provider.dart';
import 'package:qataly/state/stats_provider.dart';
import 'package:qataly/screens/splash_screen.dart';
import 'package:qataly/screens/login_screen.dart';
import 'package:qataly/screens/student_dashboard.dart';

const String _supabaseUrl = 'https://qbnzxhiuoxfnxdbpozrx.supabase.co';
const String _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibnp4aGl1b3hmbnhkYnBvenJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMjc2MzEsImV4cCI6MjEwMjcwMzYzMX0.4329lT-YSjE6fuq7maldgDEP7YLShxbd5UNxnpQ3WQg';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;
  try {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  } catch (e) {
    initError = e.toString();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChallengeProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
      ],
      child: QatalyApp(initError: initError),
    ),
  );
}

class QatalyApp extends StatelessWidget {
  final String? initError;
  const QatalyApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'قطعه',
      theme: QatalyTheme.themeData,
      debugShowCheckedModeBanner: false,
      // Arabic-first UI: RTL layout + localized Material widgets
      // (tooltips, pickers, back-button semantics...).
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Always start with the animated splash screen
      home: initError != null
          ? _SupabaseErrorScreen(error: initError!)
          : const SplashScreen(),
      // Named routes for post-splash navigation
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => Consumer<AuthProvider>(
              builder: (context, auth, _) => auth.currentUser == null
                  ? const LoginScreen()
                  : const StudentDashboard(),
            ),
      },
    );
  }
}

/// Shown only if Supabase cannot be initialized (network/config issue).
/// Offers an in-app retry instead of forcing the user to restart the app.
class _SupabaseErrorScreen extends StatefulWidget {
  final String error;
  const _SupabaseErrorScreen({required this.error});

  @override
  State<_SupabaseErrorScreen> createState() => _SupabaseErrorScreenState();
}

class _SupabaseErrorScreenState extends State<_SupabaseErrorScreen> {
  bool _isRetrying = false;
  String? _lastError;

  Future<void> _retryConnection() async {
    setState(() {
      _isRetrying = true;
      _lastError = null;
    });

    String? error;
    try {
      await Supabase.initialize(
          url: _supabaseUrl, publishableKey: _supabaseAnonKey);
    } catch (e) {
      // A second initialize() may report "already initialized" if the first
      // attempt registered the client before failing — that still means the
      // client exists and is usable, so probe it before declaring failure.
      try {
        Supabase.instance.client.auth;
      } catch (_) {
        error = e.toString();
      }
    }

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    } else {
      setState(() {
        _isRetrying = false;
        _lastError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _lastError ?? widget.error;
    return Scaffold(
      backgroundColor: QatalyTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️',
                  style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'تعذّر الاتصال بقاعدة البيانات',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'تأكد من اتصالك بالإنترنت ثم اضغط «إعادة المحاولة».',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isRetrying)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: QatalyTheme.secondary,
                  ),
                )
              else
                BrutalistButton(
                  backgroundColor: QatalyTheme.secondary,
                  onTap: _retryConnection,
                  child: const Text(
                    'إعادة المحاولة 🔄',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black38,
                child: Text(
                  error,
                  style: const TextStyle(
                      color: QatalyTheme.accent, fontSize: 11),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
