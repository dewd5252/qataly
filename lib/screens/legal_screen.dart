import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/widgets/brutalist_widgets.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/screens/login_screen.dart';

class LegalScreen extends StatefulWidget {
  final int initialTabIndex;
  const LegalScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDeleting = false;

  static const String _privacyUrl =
      'https://dewd5252.github.io/qataly/privacy.html';
  static const String _termsUrl =
      'https://dewd5252.github.io/qataly/terms.html';
  static const String _deleteAccountUrl =
      'https://dewd5252.github.io/qataly/delete-account.html';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الرابط في المتصفح'),
            backgroundColor: QatalyTheme.accent,
          ),
        );
      }
    }
  }

  void _confirmAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF131B3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: QatalyTheme.accent, width: 2),
        ),
        title: const Row(
          children: [
            Text('⚠️ ', style: TextStyle(fontSize: 22)),
            Expanded(
              child: Text(
                'حذف الحساب نهائياً',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد تماماً من رغبتك في حذف حسابك؟\n\n'
          'سيتم مسح جميع درجاتك، وتقييمك (MMR)، وسجل حل القطع، وقاموس الكلمات الصعبة فوراً وبشكل دائم.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: QatalyTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              setState(() => _isDeleting = true);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final success = await auth.deleteAccount();

              if (!mounted) return;
              setState(() => _isDeleting = false);

              if (success) {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف حسابك وجميع بياناتك بنجاح ✅'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(auth.errorMessage ?? 'حدث خطأ أثناء الحذف'),
                    backgroundColor: QatalyTheme.accent,
                  ),
                );
              }
            },
            child: const Text('نعم، احذف حسابي',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131B3E),
        elevation: 0,
        title: const Text(
          'الخصوصية والشروط والتراخيص',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: QatalyTheme.secondary,
          unselectedLabelColor: Colors.white60,
          indicatorColor: QatalyTheme.secondary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.privacy_tip_outlined, size: 20), text: 'الخصوصية'),
            Tab(icon: Icon(Icons.description_outlined, size: 20), text: 'الشروط'),
            Tab(icon: Icon(Icons.delete_forever_outlined, size: 20), text: 'حذف الحساب'),
            Tab(icon: Icon(Icons.gavel_outlined, size: 20), text: 'التراخيص'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrivacyTab(),
          _buildTermsTab(),
          _buildDeleteAccountTab(),
          _buildLicensesTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────── PRIVACY TAB ───────────────────────────
  Widget _buildPrivacyTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('🛡️ سياسة الخصوصية وأمان البيانات', 'تاريخ التحديث: 30 أغسطس 2026'),
        const SizedBox(height: 16),
        _buildCard(
          title: 'حماية بياناتك أولويتنا',
          content:
              'يلتزم تطبيق «قطعه» بحماية خصوصية الطلاب والمستخدمين وفقاً لأعلى معايير الأمان المعتمدة وسياسات Google Play.\n\n'
              '• البيانات المجمعة: معرف التيليجرام للاستيثاق، الاسم الظاهر، نقاط التقييم (MMR)، سجل حل القطع، وقاموس الكلمات الصعبة.\n'
              '• الذكاء الاصطناعي: نصوص القطع وموضوعات التدريب تُعالج عبر نماذج Google Gemini و Groq دون ربطها بهويتك الشخصية.\n'
              '• التشفير: جميع البيانات مشفرة بالكامل عبر بروتوكولات HTTPS / TLS 1.3 مع تطبيق قواعد الأمان الصارمة (Row-Level Security).',
        ),
        const SizedBox(height: 16),
        BrutalistButton(
          backgroundColor: QatalyTheme.cardBase,
          onTap: () => _launchUrl(_privacyUrl),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_browser, color: QatalyTheme.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'قراءة سياسة الخصوصية الكاملة عبر الويب 🌐',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildContactFooter(),
      ],
    );
  }

  // ─────────────────────────────── TERMS TAB ─────────────────────────────
  Widget _buildTermsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('📜 شروط الاستخدام والخدمة', 'اتفاقية الاستخدام التعليمي'),
        const SizedBox(height: 16),
        _buildCard(
          title: 'شروط استخدام المنصة',
          content:
              '• الغرض التعليمي: تطبيق قطعه مخصص لتدريب طلاب الثانوية العامة والشهادات المعادلة على مهارات الفهم القرائي باللغة الإنجليزية.\n'
              '• الاستخدام العادل: يُحظر استخدام أي برامج روبوت أو أدوات استخراج آلية للتلاعب بلوحة المتصدرين أو الدرجات.\n'
              '• الملكية الفكرية: جميع التصميمات والخوارزميات والهوية البصرية مملوكة لفريق تطوير قطعه.\n'
              '• أكواد التفعيل: صالحة للاستخدام المحدد لها ولا يجوز إعادة تداولها بصورة غير نظامية.',
        ),
        const SizedBox(height: 16),
        BrutalistButton(
          backgroundColor: QatalyTheme.cardBase,
          onTap: () => _launchUrl(_termsUrl),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_browser, color: QatalyTheme.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'استعراض وثيقة الشروط الكاملة عبر الويب 🌐',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildContactFooter(),
      ],
    );
  }

  // ─────────────────────────────── DELETE ACCOUNT TAB ────────────────────
  Widget _buildDeleteAccountTab() {
    final user = Provider.of<AuthProvider>(context).currentUser;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('🗑️ حذف الحساب والبيانات', 'متوافق مع سياسة Google Play Data Safety'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: QatalyTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: QatalyTheme.accent.withValues(alpha: 0.4), width: 1.5),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: QatalyTheme.accent, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'تنبيه الحذف النهائي',
                    style: TextStyle(
                      color: QatalyTheme.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'حذف الحساب يمسح نهائياً وبدون رجعة:\n'
                '• ملفك الشخصي واسمك\n'
                '• تقييم مهاراتك ونقاط الـ MMR\n'
                '• كامل سجل تدريباتك وحلول القطع\n'
                '• قاموس الكلمات التي أخطأت فيها',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (user != null) ...[
          if (_isDeleting)
            const Center(
              child: CircularProgressIndicator(color: QatalyTheme.accent),
            )
          else
            BrutalistButton(
              backgroundColor: QatalyTheme.accent,
              onTap: () => _confirmAccountDeletion(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_forever, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'تأكيد حذف حسابي نهائياً 🗑️',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
        ] else
          const Center(
            child: Text(
              'أنت غير مسجل الدخول حالياً.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        const SizedBox(height: 24),
        BrutalistButton(
          backgroundColor: QatalyTheme.cardBase,
          onTap: () => _launchUrl(_deleteAccountUrl),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link, color: QatalyTheme.secondary, size: 20),
              SizedBox(width: 8),
              Text(
                'صفحة طلب الحذف عبر الويب (Web Form) 🌐',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────── LICENSES TAB ──────────────────────────
  Widget _buildLicensesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('⚖️ تراخيص البرمجيات والمصادر المفتوحة', 'إقرارات الحزم والمكتبات'),
        const SizedBox(height: 16),
        _buildCard(
          title: 'البرمجيات الحرة ومفتوحة المصدر',
          content:
              'تم بناء تطبيق «قطعه» باستخدام أحدث تقنيات المصادر المفتوحة:\n\n'
              '• Flutter Framework & Dart SDK (BSD 3-Clause)\n'
              '• Supabase Flutter Client (MIT License)\n'
              '• Provider State Management (MIT License)\n'
              '• Google Fonts Cairo & Inter (Apache 2.0 / SIL OFL)\n'
              '• Crypto & HTTP (BSD 3-Clause)',
        ),
        const SizedBox(height: 16),
        BrutalistButton(
          backgroundColor: const Color(0xFF7C3AED),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'قطعه (Qata\'ly)',
              applicationVersion: '2.5.0',
              applicationLegalese: '© 2026 zed32 devs / abo wehidy. جميع الحقوق محفوظة.',
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'عرض سجل التراخيص الرسمي بالتفصيل 📜',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildContactFooter(),
      ],
    );
  }

  // ─────────────────────────────── HELPERS ───────────────────────────────
  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: QatalyTheme.secondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF131B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3875), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1430),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3875)),
      ),
      child: const Column(
        children: [
          Text(
            'تطبيق قطعه (Qata\'ly) — دعم متجر Google Play',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            '📧 support@qataly.app | mmooup67@gmail.com',
            style: TextStyle(color: QatalyTheme.secondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
