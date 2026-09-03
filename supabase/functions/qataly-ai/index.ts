// Supabase Edge Function: qataly-ai
// Secure AI proxy that rotates Gemini 3.5 Flash-Lite API keys
// Keys are loaded exclusively from Supabase Environment Secrets (GEMINI_KEYS).
// ZERO secrets in this file or repository.

const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

// Exclusively Gemini 3.5 Flash Lite
const GEMINI_MODELS = ['gemini-3.5-flash-lite'];

function getApiKeys(): string[] {
  const envKeys = Deno.env.get('GEMINI_KEYS');
  if (envKeys && envKeys.trim().length > 0) {
    return envKeys.split(',').map((k) => k.trim()).filter(Boolean);
  }
  throw new Error('GEMINI_KEYS secret is not configured in Supabase Edge Function environment.');
}

let keyIndex = 0;

async function callGemini(prompt: string, jsonMode = false): Promise<string> {
  const keys = getApiKeys();
  let lastError: unknown;

  // Try each key with rotating start index
  for (let attempt = 0; attempt < keys.length; attempt++) {
    const currentKey = keys[(keyIndex + attempt) % keys.length];

    for (const model of GEMINI_MODELS) {
      try {
        const url = `${GEMINI_BASE_URL}/${model}:generateContent?key=${currentKey}`;
        const genConfig: Record<string, unknown> = {
          temperature: 0.7,
          maxOutputTokens: 3072,
        };

        if (jsonMode) {
          genConfig['responseMimeType'] = 'application/json';
        }

        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [
              {
                parts: [{ text: prompt }],
              },
            ],
            generationConfig: genConfig,
          }),
        });

        if (!res.ok) {
          const errText = await res.text();
          console.warn(`Gemini [${model}] error ${res.status}: ${errText}`);
          lastError = `[${model}] ${res.status}: ${errText}`;
          continue;
        }

        const data = await res.json();
        const candidate = data.candidates?.[0];
        const text = candidate?.content?.parts?.[0]?.text;

        if (text && text.trim().length > 0) {
          // Advance rotation index for next call
          keyIndex = (keyIndex + attempt + 1) % keys.length;
          return text.trim();
        }
      } catch (err) {
        console.warn(`Failed call with model ${model}:`, err);
        lastError = err;
      }
    }
  }

  throw new Error(`All Gemini models/keys failed. Last error: ${lastError}`);
}

function parseJsonSafely(text: string): Record<string, unknown> {
  let cleaned = text
    .replace(/^```json\s*/gm, '')
    .replace(/^```\s*/gm, '')
    .trim();

  const firstBrace = cleaned.indexOf('{');
  const lastBrace = cleaned.lastIndexOf('}');
  if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
    cleaned = cleaned.substring(firstBrace, lastBrace + 1);
  }

  return JSON.parse(cleaned);
}

const TOPICS = [
  'Space Exploration and Mars Missions',
  'Artificial Intelligence and the Future of Jobs',
  'Renewable Energy and Climate Change Solutions',
  'Ancient Egyptian History and Pyramids Architecture',
  'Cybersecurity and Digital Privacy in the Modern World',
  'Mental Health and Daily Healthy Habits',
  'Ocean Exploration and Deep Sea Ecosystems',
  'Global Economic Trends and E-Commerce Innovation',
];

Deno.serve(async (req: Request) => {
  // CORS Headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { action, payload } = await req.json();

    if (action === 'translate_word') {
      const { word, passage_context } = payload ?? {};
      const contextHint = passage_context
        ? `\nسياق الاستخدام في الجملة: "${passage_context}"`
        : '';
      const prompt = `
أنت معلم لغة إنجليزية متخصص في الثانوية العامة المصرية.
اشرح الكلمة الإنجليزية التالية بالعامية المصرية البسيطة في 2-3 أسطر فقط.
الكلمة: "${word}"${contextHint}

الصيغة المطلوبة (لا تغيرها):
📌 المعنى: [المعنى بالعربي]
💡 في السياق: [شرح استخدامها في الجملة]
🔥 للامتحان: [ملاحظة سريعة إن وجدت]
`;
      const translation = await callGemini(prompt, false);
      return new Response(JSON.stringify({ result: translation }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (action === 'generate_passage') {
      const { difficulty_level = 3, topic, num_questions = 6 } = payload ?? {};
      const selectedTopic = topic || TOPICS[Math.floor(Math.random() * TOPICS.length)];

      const levelDescriptions: Record<number, string> = {
        1: 'very simple (elementary vocabulary, short sentences)',
        2: 'easy (middle school level, clear grammar)',
        3: 'intermediate (Egyptian Secondary 1/2 exam level)',
        4: 'hard (Egyptian Thanawya Amma Final Exam level, complex idioms)',
        5: 'very hard (advanced academic English, complex vocabulary)',
      };
      const levelDesc = levelDescriptions[difficulty_level] || 'intermediate';

      const prompt = `
You are an expert Egyptian Thanawya Amma English exam creator.

Generate a brand-new reading comprehension passage on topic "${selectedTopic}" tailored for difficulty level ${difficulty_level} (${levelDesc}).
The passage should be 120-180 words long.

Then generate EXACTLY ${num_questions} multiple-choice questions (MCQs) based on the passage.
Each question MUST have 4 options: "A", "B", "C", and "D".
Provide a clear explanation in encouraging Egyptian colloquial Arabic (عامية مصرية تشجيعية بسيطة) for each question.

IMPORTANT: Return ONLY raw valid JSON, no markdown formatting (no \`\`\`json codeblocks), no introductory or concluding text.

JSON Schema:
{
  "passage_text": "The full passage text...",
  "difficulty_level": ${difficulty_level},
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
`;
      const raw = await callGemini(prompt, true);
      const parsed = parseJsonSafely(raw);
      parsed.difficulty_level = difficulty_level;

      return new Response(JSON.stringify(parsed), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (action === 'correct_essay') {
      const { text } = payload ?? {};
      const prompt = `
You are an expert Egyptian English teacher reviewing a student's daily English journal/essay.
Analyze the following text written by a student:
"${text}"

Check for grammar, spelling, vocabulary, and sentence structure mistakes.
Provide feedback in Egyptian colloquial Arabic (عامية مصرية مشجعة).

IMPORTANT: Return ONLY valid JSON, no markdown codeblocks. Use this exact schema:
{
  "corrected": "The fully corrected English text here",
  "explanation": "الشرح والملاحظات بالعامية المصرية البسيطة المشجعة...",
  "score": 85
}
`;
      const raw = await callGemini(prompt, true);
      try {
        const parsed = parseJsonSafely(raw);
        return new Response(JSON.stringify(parsed), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } catch {
        return new Response(
          JSON.stringify({
            corrected: text,
            explanation: `تم فحص النص بالذكاء الاصطناعي: ${raw}`,
            score: 90,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    return new Response(JSON.stringify({ error: `Unknown action: ${action}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('qataly-ai function error:', err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
