import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Multi-Provider AI Service powering Qata'ly:
/// Combines Groq LPU (llama-3.3-70b-versatile) and Gemini 3.5 Flash
/// with Round-Robin Rotation and automatic Failover Fallback.
class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  // Groq LPU Provider Details
  static const String _groqApiKey =
      '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';
  static const String _groqModel = 'llama-3.3-70b-versatile';
  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Gemini 3.5 Flash Provider Details
  static const String _geminiApiKey =
      'AQ.Ab8RN6KXF_tEy3bOS8Ej6mZDed2ILMwSnCpU2ObFWv_io3gDMQ';
  static const String _geminiModel = 'gemini-3.5-flash';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent';

  final Random _random = Random();
  int _providerCounter = 0;

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
  // Core Generation with Provider Rotation & Fallback
  // ─────────────────────────────────────────────────────────────

  Future<String> _generate(String prompt, {bool jsonMode = false}) async {
    _providerCounter++;
    final useGroqFirst = (_providerCounter % 2 == 1);

    if (useGroqFirst) {
      try {
        return await _generateGroq(prompt, jsonMode: jsonMode);
      } catch (e) {
        debugPrint('Groq LPU failed ($e), falling back to Gemini 3.5 Flash...');
        return await _generateGemini(prompt, jsonMode: jsonMode);
      }
    } else {
      try {
        return await _generateGemini(prompt, jsonMode: jsonMode);
      } catch (e) {
        debugPrint('Gemini 3.5 Flash failed ($e), falling back to Groq LPU...');
        return await _generateGroq(prompt, jsonMode: jsonMode);
      }
    }
  }

  /// 1. Groq LPU Generator
  Future<String> _generateGroq(String prompt, {bool jsonMode = false}) async {
    final uri = Uri.parse(_groqUrl);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_groqApiKey',
    };

    final Map<String, dynamic> bodyMap = {
      'model': _groqModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.7,
      'max_tokens': 3072,
    };

    if (jsonMode) {
      bodyMap['response_format'] = {'type': 'json_object'};
    }

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(bodyMap))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Groq API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('لا توجد استجابة من Groq LPU');
    }
    final message = choices[0]['message'] as Map<String, dynamic>;
    return (message['content'] as String).trim();
  }

  /// 2. Gemini 3.5 Flash Generator
  Future<String> _generateGemini(String prompt, {bool jsonMode = false}) async {
    final uri = Uri.parse('$_geminiUrl?key=$_geminiApiKey');
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

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Gemini API Error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('لا توجد استجابة من Gemini 3.5 Flash');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;
    return (parts[0]['text'] as String).trim();
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Translate / explain a word in Egyptian colloquial Arabic
  // ─────────────────────────────────────────────────────────────
  Future<String> translateWord(String word, {String? passageContext}) async {
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
