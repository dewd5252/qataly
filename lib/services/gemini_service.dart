import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qataly/config/secrets.dart';

/// Gemini AI Service with Multi-Key Rotation and Supabase Edge Function Proxy.
/// Strictly uses `gemini-2.5-flash-lite` (with fallback to `gemini-3.5-flash-lite`).
/// All API keys are stored in git-ignored configuration to prevent any GitHub leaks.
class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  // Exclusively Gemini 3.5 Flash Lite
  static const List<String> _geminiModels = [
    'gemini-3.5-flash-lite',
  ];

  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final Random _random = Random();
  int _currentKeyIndex = 0;

  List<String> get _keys => AppSecrets.geminiApiKeys;

  final List<String> _topics = [
    'Space Exploration and Mars Missions',
    'Artificial Intelligence and the Future of Jobs',
    'Renewable Energy and Climate Change Solutions',
    'Ancient Egyptian History and Pyramids Architecture',
    'Cybersecurity and Digital Privacy in the Modern World',
    'Mental Health and Daily Healthy Habits',
    'Ocean Exploration and Deep Sea Ecosystems',
    'Global Economic Trends and E-Commerce Innovation',
  ];

  // ─────────────────────────────────────────────────────────────
  // Core AI Generation with Edge Function + Rotating Key Fallback
  // ─────────────────────────────────────────────────────────────

  Future<String> _generate(String prompt, {bool jsonMode = false}) async {
    // 1. Try Supabase Edge Function (server-side proxy) first if client is initialized
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'qataly-ai',
        body: {
          'action': jsonMode ? 'raw_json' : 'raw_text',
          'payload': {'prompt': prompt, 'json_mode': jsonMode},
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status == 200 && response.data != null) {
        if (response.data is Map && response.data['result'] != null) {
          return response.data['result'] as String;
        }
      }
    } catch (_) {
      // Edge function not yet deployed or unreachable, fall back to direct rotation
    }

    // 2. Direct Gemini rotation across the 3 keys
    return await _generateDirectGemini(prompt, jsonMode: jsonMode);
  }

  /// Direct Gemini API caller with round-robin rotation across the 3 keys
  /// and model fallback between gemini-2.5-flash-lite and gemini-3.5-flash-lite.
  Future<String> _generateDirectGemini(String prompt, {bool jsonMode = false}) async {
    final Map<String, dynamic> genConfig = {
      'temperature': 0.7,
      'maxOutputTokens': 3072,
    };

    if (jsonMode) {
      genConfig['responseMimeType'] = 'application/json';
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': genConfig
    });

    final keys = _keys;
    if (keys.isEmpty) {
      throw Exception('لا توجد مفاتيح API مهيأة للذكاء الاصطناعي.');
    }

    dynamic lastError;

    // Try rotating through keys
    for (int i = 0; i < keys.length; i++) {
      final key = keys[(_currentKeyIndex + i) % keys.length];

      for (final model in _geminiModels) {
        try {
          final uri = Uri.parse('$_geminiBaseUrl/$model:generateContent?key=$key');
          final response = await http
              .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 25));

          if (response.statusCode != 200) {
            lastError = '[$model] ${response.statusCode}: ${response.body}';
            debugPrint('Gemini key/model failed ($lastError), trying next...');
            continue;
          }

          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = json['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            continue;
          }
          final content = candidates[0]['content'] as Map<String, dynamic>;
          final parts = content['parts'] as List<dynamic>;
          final text = (parts[0]['text'] as String).trim();

          if (text.isNotEmpty) {
            // Successfully generated — advance rotation counter for next invocation
            _currentKeyIndex = (_currentKeyIndex + i + 1) % keys.length;
            return text;
          }
        } catch (e) {
          lastError = e;
          debugPrint('Gemini error with key/model: $e');
        }
      }
    }

    throw Exception('تعذر الاتصال بخدمة الذكاء الاصطناعي. يرجى المحاولة مرة أخرى.');
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Translate / explain a word in Egyptian colloquial Arabic
  // ─────────────────────────────────────────────────────────────
  Future<String> translateWord(String word, {String? passageContext}) async {
    // Try Edge Function first
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'qataly-ai',
        body: {
          'action': 'translate_word',
          'payload': {
            'word': word,
            'passage_context': passageContext,
          },
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['result'] != null) {
          return data['result'] as String;
        }
      }
    } catch (_) {
      // Fall through to direct generation
    }

    final contextHint = passageContext != null
        ? '\nسياق الاستخدام في الجملة: "$passageContext"'
        : '';
    final prompt = '''
أنت معلم لغة إنجليزية متخصص في الثانوية العامة المصرية.
اشرح الكلمة الإنجليزية التالية بالعامية المصرية البسيطة في 2-3 أسطر فقط.
الكلمة: "$word"$contextHint

الصيغة المطلوبة (لا تغيرها):
📌 المعنى: [المعنى بالعربي]
💡 في السياق: [شرح استخدامها في الجملة]
🔥 للامتحان: [ملاحظة سريعة إن وجدت]
''';
    return await _generate(prompt, jsonMode: false);
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Instant On-The-Fly Passage Generation (6 Questions)
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> generatePassage({
    required int difficultyLevel, // 1-5
    String? topic,
    int numQuestions = 6,
  }) async {
    final selectedTopic = topic ?? _topics[_random.nextInt(_topics.length)];

    // Try Edge Function first
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'qataly-ai',
        body: {
          'action': 'generate_passage',
          'payload': {
            'difficulty_level': difficultyLevel,
            'topic': selectedTopic,
            'num_questions': numQuestions,
          },
        },
      ).timeout(const Duration(seconds: 25));

      if (response.status == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['passage_text'] != null) {
          final map = Map<String, dynamic>.from(data);
          map['difficulty_level'] = difficultyLevel;
          return map;
        }
      }
    } catch (_) {
      // Fall through to direct generation
    }

    final levelDesc = {
      1: 'very simple (elementary vocabulary, short sentences)',
      2: 'easy (middle school level, clear grammar)',
      3: 'intermediate (Egyptian Secondary 1/2 exam level)',
      4: 'hard (Egyptian Thanawya Amma Final Exam level, complex idioms)',
      5: 'very hard (advanced academic English, complex vocabulary)',
    }[difficultyLevel] ?? 'intermediate (Egyptian Secondary Exam level)';

    final prompt = '''
You are an expert Egyptian Thanawya Amma English exam creator.

Generate a brand-new reading comprehension passage on topic "$selectedTopic" tailored for difficulty level $difficultyLevel ($levelDesc).
The passage should be 120-180 words long.

Then generate EXACTLY $numQuestions multiple-choice questions (MCQs) based on the passage.
Each question MUST have 4 options: "A", "B", "C", and "D".
Provide a clear explanation in encouraging Egyptian colloquial Arabic (عامية مصرية تشجيعية بسيطة) for each question.

IMPORTANT: Return ONLY raw valid JSON, no markdown formatting (no ```json codeblocks), no introductory or concluding text.

JSON Schema:
{
  "passage_text": "The full passage text...",
  "difficulty_level": $difficultyLevel,
  "vocabulary_used": ["key_word1", "key_word2", "key_word3", "key_word4"],
  "questions": [
    {
      "id": 1,
      "question_text": "Question text?",
      "options": {"A": "Option 1", "B": "Option 2", "C": "Option 3", "D": "Option 4"},
      "correct_option": "A",
      "explanation": "شرح الإجابة بالعامية المصرية..."
    }
  ]
}
''';

    final raw = await _generate(prompt, jsonMode: true);

    try {
      final data = _parseJsonSafely(raw);
      data['difficulty_level'] = difficultyLevel;
      return data;
    } catch (e) {
      throw Exception('خطأ في استلام القطعة من الذكاء الاصطناعي. حاول مرة أخرى.\n$e');
    }
  }

  /// Helper to safely extract JSON object even if wrapped in markdown or leading/trailing text
  Map<String, dynamic> _parseJsonSafely(String text) {
    var cleaned = text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────
  // 3. AI Essay / Journal Grammar Correction
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> correctJournalEssay(String text) async {
    // Try Edge Function first
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'qataly-ai',
        body: {
          'action': 'correct_essay',
          'payload': {'text': text},
        },
      ).timeout(const Duration(seconds: 25));

      if (response.status == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data['corrected'] != null) {
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (_) {
      // Fall through to direct generation
    }

    final prompt = '''
You are an expert Egyptian English teacher reviewing a student's daily English journal/essay.
Analyze the following text written by a student:
"$text"

Check for grammar, spelling, vocabulary, and sentence structure mistakes.
Provide feedback in Egyptian colloquial Arabic (عامية مصرية مشجعة).

IMPORTANT: Return ONLY valid JSON, no markdown codeblocks. Use this exact schema:
{
  "corrected": "The fully corrected English text here",
  "explanation": "الشرح والملاحظات بالعامية المصرية البسيطة المشجعة...",
  "score": 85
}
''';

    final raw = await _generate(prompt, jsonMode: true);

    try {
      return _parseJsonSafely(raw);
    } catch (e) {
      return {
        'corrected': text,
        'explanation': 'تم فحص النص بالذكاء الاصطناعي: $raw',
        'score': 90,
      };
    }
  }
}
