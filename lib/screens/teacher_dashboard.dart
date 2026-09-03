import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qataly/models/profile.dart';
import 'package:qataly/services/gemini_service.dart';
import 'package:qataly/services/supabase_service.dart';
import 'package:qataly/state/auth_provider.dart';
import 'package:qataly/state/stats_provider.dart';
import 'package:qataly/theme.dart';
import 'package:qataly/widgets/brutalist_widgets.dart';
import 'package:share_plus/share_plus.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  bool _isExporting = false;
  bool _isGeneratingAiPassage = false;

  // Student table search + sorting
  final _studentSearchController = TextEditingController();
  int _sortColumn = 2; // 0=rank, 1=name, 2=mmr, 3=streak
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _studentSearchController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClassroomData();
    });
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  /// The dashboard used to render zeros because it never loaded any data —
  /// both the classroom roster and the weak-words aggregation live here.
  Future<void> _loadClassroomData() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final classroomId = user?.classroomId;
    final stats = Provider.of<StatsProvider>(context, listen: false);
    if ((classroomId ?? '').isNotEmpty) {
      await stats.loadClassroomData(classroomId!);
      await stats.loadTopClassWeakWords(classroomId);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CSV export: real file + share sheet (clipboard kept as fallback).
  // ─────────────────────────────────────────────────────────────
  String _csvEscape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  String _buildCsv(List<Profile> leaderboard) {
    // UTF-8 BOM so Excel renders the Arabic headers correctly.
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('الترتيب,اسم الطالب,مستوى MMR,سلسلة الأيام Streak,الحالة البريميوم');
    for (int i = 0; i < leaderboard.length; i++) {
      final s = leaderboard[i];
      buffer.writeln(
          '${i + 1},${_csvEscape(s.fullName)},${s.mmr},${s.dailyStreak},${s.isPremium ? "Premium" : "Free"}');
    }
    return buffer.toString();
  }

  Future<void> _exportToExcel(StatsProvider stats) async {
    setState(() => _isExporting = true);

    try {
      final csvContent = _buildCsv(stats.classroomLeaderboard);
      await Clipboard.setData(ClipboardData(text: csvContent));

      if (!kIsWeb) {
        // Real CSV file + native share/save sheet.
        final dir = await getTemporaryDirectory();
        final now = DateTime.now();
        final stamp = '${now.year}'
            '${now.month.toString().padLeft(2, '0')}'
            '${now.day.toString().padLeft(2, '0')}';
        final file = File('${dir.path}/qataly_students_$stamp.csv');
        await file.writeAsString(csvContent);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: 'تقرير طلاب قطعلي 📊'),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: QatalyTheme.secondary,
            content: const Text(
              'تم تجهيز ملف CSV ومشاركته، ونسخة احتياطية في الحافظة 📥',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: QatalyTheme.accent,
            content: Text(
              'فشل التصدير: ${e.toString().replaceAll("Exception: ", "")}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isExporting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Student drill-down: profile + recent challenge history.
  // ─────────────────────────────────────────────────────────────
  void _showStudentDetails(Profile student) {
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
                    Expanded(
                      child: Text(
                        '👤 ${student.fullName}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: QatalyTheme.secondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _detailStat('الرتبة', student.rank.toUpperCase()),
                    _detailStat('MMR', '${student.mmr}'),
                    _detailStat('الستريك', '🔥 ${student.dailyStreak}'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  student.isPremium ? '👑 عضوية بريميوم نشطة' : '💎 حساب مجاني',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: student.isPremium ? QatalyTheme.secondary : Colors.white54,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'آخر التحديات المحلولة:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: SupabaseService.instance.getStudentProgress(student.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: QatalyTheme.secondary),
                        ),
                      );
                    }
                    final rows = snapshot.data;
                    if (rows == null || rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'لسه محلوش أي تحدي 🤷',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final p = rows[index];
                          final diff = p.newMmr - p.oldMmr;
                          final date = p.solvedAt.toLocal();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${date.year}/${date.month}/${date.day}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'الدرجة: ${p.scorePercentage.round()}%',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: QatalyTheme.secondary),
                                ),
                                Text(
                                  '${diff >= 0 ? "+" : ""}$diff MMR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: diff >= 0 ? QatalyTheme.secondary : QatalyTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                BrutalistButton(
                  height: 40,
                  backgroundColor: QatalyTheme.secondary,
                  onTap: () => Navigator.pop(context),
                  child: const Text('إغلاق 🔗', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: QatalyTheme.secondary),
          ),
        ),
      ],
    );
  }

  void _showGenerateAiPassageDialog() {
    final topicController = TextEditingController(text: 'Artificial Intelligence in Medicine');
    int selectedDifficulty = 3;

    showDialog(
      context: context,
      barrierDismissible: !_isGeneratingAiPassage,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
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
                          'توليد قطعة بالذكاء الاصطناعي 🤖',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: QatalyTheme.secondary,
                          ),
                        ),
                        if (!_isGeneratingAiPassage)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'سيتم إنشاء قطعة قراءة جديدة تماماً مع الأسئلة والخيارات والشروحات وتخزينها في قاعدة البيانات مباشرة:',
                      style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Topic Input
                    BrutalistInput(
                      controller: topicController,
                      hintText: 'موضوع القطعة (بالإنكليزية)',
                      prefixIcon: Icons.topic_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Difficulty selector
                    const Text('مستوى الصعوبة (1 - 5):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(5, (index) {
                        final level = index + 1;
                        final isSelected = level == selectedDifficulty;
                        return InkWell(
                          onTap: () => setDialogState(() => selectedDifficulty = level),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? QatalyTheme.primary : Colors.black26,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Text(
                              '$level',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.white60,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    if (_isGeneratingAiPassage)
                      const Column(
                        children: [
                          CircularProgressIndicator(color: QatalyTheme.primary),
                          SizedBox(height: 12),
                          Text(
                            'جاري إعداد وصياغة القطعة والأسئلة والترجمة...',
                            style: TextStyle(color: QatalyTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else
                      BrutalistButton(
                        backgroundColor: QatalyTheme.primary,
                        onTap: () async {
                          final topic = topicController.text.trim();
                          if (topic.isEmpty) return;

                          setDialogState(() => _isGeneratingAiPassage = true);

                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            // 1. Call Gemini AI
                            final generatedData = await GeminiService.instance.generatePassage(
                              difficultyLevel: selectedDifficulty,
                              topic: topic,
                            );

                            // 2. Save directly to Supabase production database
                            await SupabaseService.instance.savePassage(generatedData);

                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: QatalyTheme.secondary,
                                content: Text(
                                  '🎉 تم توليد القطعة وحفظها بنجاح في منصة Supabase!',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => _isGeneratingAiPassage = false);
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: QatalyTheme.accent,
                                content: Text(
                                  'فشل التوليد: ${e.toString().replaceAll("Exception: ", "")}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'توليد ونشر على Supabase 🚀',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Profile> _filteredStudents(StatsProvider stats) {
    final query = _studentSearchController.text.trim().toLowerCase();
    var students = stats.classroomLeaderboard
        .where((s) => query.isEmpty || s.fullName.toLowerCase().contains(query))
        .toList();

    int compare(Profile a, Profile b) {
      switch (_sortColumn) {
        case 1:
          return a.fullName.compareTo(b.fullName);
        case 2:
          return a.mmr.compareTo(b.mmr);
        case 3:
          return a.dailyStreak.compareTo(b.dailyStreak);
        default:
          return 0; // keep rank order
      }
    }

    students.sort(compare);
    if (!_sortAsc) {
      students = students.reversed.toList();
    }
    // Rank column always ascending — restore natural order when sorting by rank.
    if (_sortColumn == 0) {
      students = stats.classroomLeaderboard
          .where((s) => query.isEmpty || s.fullName.toLowerCase().contains(query))
          .toList();
    }
    return students;
  }

  @override
  Widget build(BuildContext context) {
    final stats = Provider.of<StatsProvider>(context);
    final user = Provider.of<AuthProvider>(context).currentUser;
    final hasClassroom = (user?.classroomId ?? '').isNotEmpty;

    if (stats.isLoading && stats.classroomLeaderboard.isEmpty && hasClassroom) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('لوحة تحكم المستر 📊', style: TextStyle(fontWeight: FontWeight.w900)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: QatalyTheme.secondary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('لوحة تحكم المستر 📊 (Web Panel)', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasClassroom) ...[
                BrutalistCard(
                  backgroundColor: QatalyTheme.cardBase,
                  child: Column(
                    children: const [
                      Text('🎓', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text(
                        'لوحة المعلم محتاجة تكون راكب في فصل الأول',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'ادخل كود السنتر من تبويب الإعدادات في حسابك، وارجع افتح اللوحة تاني.',
                        style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Statistics Row
              Row(
                children: [
                  Expanded(
                    child: BrutalistCard(
                      backgroundColor: QatalyTheme.cardBase,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        children: [
                          const Text('الطلاب النشطين', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${stats.totalActiveStudents}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: QatalyTheme.secondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BrutalistCard(
                      backgroundColor: QatalyTheme.cardBase,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        children: [
                          const Text('متوسط الـ MMR', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${stats.averageMmr.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: QatalyTheme.primary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BrutalistCard(
                      backgroundColor: QatalyTheme.cardBase,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Column(
                        children: [
                          const Text('متوسط الـ Streak', style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${stats.averageStreak.round()} يوم', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: QatalyTheme.accent)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // AI Passage Generator Trigger Button
              BrutalistButton(
                backgroundColor: QatalyTheme.primary,
                onTap: _showGenerateAiPassageDialog,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'توليد قطعة جديدة بالذكاء الاصطناعي 🤖',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Top 5 Class Weak Words (real aggregation via top_weak_words RPC)
              BrutalistCard(
                backgroundColor: QatalyTheme.cardBase,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: QatalyTheme.accent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'أكثر 5 كلمات أخطأ فيها الطلاب ⚠️',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (stats.topClassWeakWords.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'مفيش بيانات أخطاء للفصل لسه — أول ما الطلاب يبدأوا يحلوا، أكثر الكلمات المُربكة هتظهر هنا تلقائيًا.',
                          style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: stats.topClassWeakWords.length,
                        itemBuilder: (context, index) {
                          final item = stats.topClassWeakWords[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      '${index + 1}. ${item['word']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.black26, border: Border.all(color: Colors.black)),
                                      child: Text('${item['students']} طالب', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${item['mistakes']} خطأ',
                                      style: const TextStyle(color: QatalyTheme.accent, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Export Data button
              _isExporting
                  ? const Center(child: CircularProgressIndicator(color: QatalyTheme.primary))
                  : BrutalistButton(
                      backgroundColor: QatalyTheme.secondary,
                      onTap: () => _exportToExcel(stats),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download, color: Colors.black),
                          SizedBox(width: 8),
                          Text('تصدير بيانات الطلاب CSV (مشاركة + حافظة) 📊', style: TextStyle(color: Colors.black, fontSize: 14)),
                        ],
                      ),
                    ),
              const SizedBox(height: 20),

              // Student table
              const Text(
                '👤 جدول بيانات الطلاب التفصيلي:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              BrutalistInput(
                controller: _studentSearchController,
                hintText: 'ابحث باسم الطالب... 🔍',
                prefixIcon: Icons.search,
              ),
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final students = _filteredStudents(stats);
                if (students.isEmpty) {
                  return BrutalistCard(
                    backgroundColor: const Color(0xFF15151A),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'مفيش طلاب مطابقين للبحث 🤔',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  );
                }
                return BrutalistCard(
                  backgroundColor: const Color(0xFF15151A),
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.black),
                      sortColumnIndex: _sortColumn,
                      sortAscending: _sortAsc,
                      columns: [
                        DataColumn(label: const Text('الترتيب', style: TextStyle(fontWeight: FontWeight.bold, color: QatalyTheme.secondary)),
                            onSort: (col, asc) => setState(() { _sortColumn = 0; _sortAsc = true; })),
                        DataColumn(label: const Text('الاسم الكامل', style: TextStyle(fontWeight: FontWeight.bold)),
                            onSort: (col, asc) => setState(() { _sortColumn = 1; _sortAsc = asc; })),
                        DataColumn(
                          label: const Text('الـ MMR الحالي', style: TextStyle(fontWeight: FontWeight.bold, color: QatalyTheme.secondary)),
                          onSort: (col, asc) => setState(() { _sortColumn = 2; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: const Text('الـ Streak', style: TextStyle(fontWeight: FontWeight.bold)),
                          onSort: (col, asc) => setState(() { _sortColumn = 3; _sortAsc = asc; }),
                        ),
                        const DataColumn(label: Text('الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: List.generate(students.length, (index) {
                        final s = students[index];
                        return DataRow(
                          onSelectChanged: (_) => _showStudentDetails(s),
                          cells: [
                            DataCell(Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)))),
                            DataCell(Text(s.fullName)),
                            DataCell(Text('${s.mmr}', style: const TextStyle(fontWeight: FontWeight.w900, color: QatalyTheme.secondary))),
                            DataCell(Text('🔥 ${s.dailyStreak}')),
                            DataCell(Text(s.isPremium ? '👑 Premium' : 'Free', style: TextStyle(color: s.isPremium ? QatalyTheme.secondary : Colors.white60))),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
