import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/services/telegram_auth_service.dart';
import 'package:qataly/screens/student_dashboard.dart';
import 'package:qataly/theme.dart';

const String kTelegramBotUsername = 'QatalyBot';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  StreamSubscription<Uri>? _sub;
  Timer? _sessionTimer;
  bool _isProcessing = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _initDeepLinks();
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleIncomingUri(uri);
    });
    _sub = appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
  }

  void _handleIncomingUri(Uri uri) {
    debugPrint('Deep link received: $uri');
    if (uri.scheme != 'qataly' || uri.host != 'auth') return;

    final tgAuthResult = uri.queryParameters['tgAuthResult'];
    if (tgAuthResult != null && tgAuthResult.isNotEmpty) {
      _decodeTgAuthResult(tgAuthResult);
      return;
    }

    final rawData = uri.queryParameters['data'];
    if (rawData != null && rawData.isNotEmpty) {
      try {
        final jsonMap =
            jsonDecode(Uri.decodeComponent(rawData)) as Map<String, dynamic>;
        _handleAuthSuccess(TelegramUser.fromJson(jsonMap));
      } catch (e) {
        debugPrint('Legacy deep link error: $e');
      }
    }
  }

  void _decodeTgAuthResult(String tgAuthResult) {
    try {
      final padded = base64Url.normalize(tgAuthResult);
      final decoded = utf8.decode(base64Url.decode(padded));
      final jsonMap = jsonDecode(decoded) as Map<String, dynamic>;
      _handleAuthSuccess(TelegramUser.fromJson(jsonMap));
    } catch (e) {
      debugPrint('tgAuthResult decode error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sessionTimer?.cancel();
    _logoController.dispose();
    super.dispose();
  }

  /// Native Telegram Bot Direct Authentication Flow
  /// 1. Creates a session in Supabase `auth_sessions` table
  /// 2. Opens Telegram App natively to @QatalyBot with /start auth_SESSIONID
  /// 3. Polls session status until Telegram Bot Webhook completes the login
  Future<void> _startTelegramLogin() async {
    setState(() {
      _isProcessing = true;
      _statusText = 'جاري التوجيه إلى Telegram...';
    });

    final sessionId = 'auth_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Create session row in DB
      await Supabase.instance.client.from('auth_sessions').insert({
        'id': sessionId,
        'status': 'pending',
      });

      // Launch Telegram app natively
      final tgNativeUri =
          Uri.parse('tg://resolve?domain=$kTelegramBotUsername&start=$sessionId');
      final tgWebUri =
          Uri.parse('https://t.me/$kTelegramBotUsername?start=$sessionId');

      bool launched = false;
      try {
        launched =
            await launchUrl(tgNativeUri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        launched =
            await launchUrl(tgWebUri, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: QatalyTheme.accent,
              content: Text('تعذّر فتح تطبيق تليجرام. يرجى التأكد من تثبيته.',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _statusText = 'في انتظار الضغط على "بدء" (Start) في تليجرام...';
        });
      }

      // Start polling session
      _listenToSession(sessionId);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: QatalyTheme.accent,
            content: Text('خطأ: $e',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    }
  }

  void _listenToSession(String sessionId) {
    _sessionTimer?.cancel();
    int elapsed = 0;

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      elapsed++;
      if (elapsed > 120) {
        // 2 minutes timeout
        timer.cancel();
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusText = null;
          });
        }
        return;
      }

      try {
        final res = await Supabase.instance.client
            .from('auth_sessions')
            .select()
            .eq('id', sessionId)
            .maybeSingle();

        if (res != null &&
            res['status'] == 'completed' &&
            res['user_data'] != null) {
          timer.cancel();
          final userData =
              Map<String, dynamic>.from(res['user_data'] as Map);
          _handleAuthSuccess(TelegramUser.fromJson(userData));
        }
      } catch (_) {}
    });
  }

  void _handleAuthSuccess(TelegramUser tgUser) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _statusText = 'جاري تسجيل دخولك...';
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.loginWithTelegram(tgUser);

    if (!mounted) return;

    if (success) {
      // Navigation to Student Dashboard after successful Telegram login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentDashboard()),
      );
    } else {
      setState(() {
        _isProcessing = false;
        _statusText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: QatalyTheme.accent,
          content: Text(
            auth.errorMessage ?? 'فشل تسجيل الدخول. حاول مرة أخرى.',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: _buildLandingScreen(),
    );
  }

  Widget _buildLandingScreen() {
    final auth = Provider.of<AuthProvider>(context);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) => Transform.scale(
                    scale: _logoController.value,
                    child: child,
                  ),
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black45,
                              offset: Offset(0, 8),
                              blurRadius: 16)
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset('assets/images/logo.jpg',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'قطعه',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'حل وتدريب على أسئلة قطعة اللغة الإنجليزية',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5B8EE6),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),

              const _FeatureRow(
                  icon: '⚡', text: 'قطع مخصصة بالذكاء الاصطناعي لمستواك'),
              const SizedBox(height: 12),
              const _FeatureRow(
                  icon: '🏆', text: 'تنافس مع أفضل الطلاب على مستوى مصر'),
              const SizedBox(height: 12),
              const _FeatureRow(
                  icon: '📚', text: 'قاموس ضعفك الشخصي التفاعلي بالـ AI'),
              const SizedBox(height: 12),
              const _FeatureRow(
                  icon: '✨', text: 'تصحيح وتدريب التعبير الإنجليزي فوراً'),
              const SizedBox(height: 40),

              if (auth.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: QatalyTheme.accent.withValues(alpha: 0.15),
                    border: Border.all(color: QatalyTheme.accent, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    auth.errorMessage!,
                    style: const TextStyle(
                        color: QatalyTheme.accent,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (auth.isLoading || _isProcessing)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF229ED9)),
                      const SizedBox(height: 14),
                      Text(
                        _statusText ?? 'جاري التوثيق... ✈️',
                        style: const TextStyle(
                          color: Color(0xFF229ED9),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                _TelegramLoginButton(onPressed: _startTelegramLogin),

              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'سيفتح تطبيق تليجرام لموافقتك بنقرة واحدة',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  '— zed32 devs / abo wehidy —',
                  style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3875), width: 1.5),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelegramLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _TelegramLoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF229ED9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 8,
        shadowColor: const Color(0xFF229ED9).withValues(alpha: 0.4),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('✈️', style: TextStyle(fontSize: 22)),
          SizedBox(width: 12),
          Text(
            'تسجيل الدخول عبر Telegram',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
