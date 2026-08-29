// Supabase Edge Function: telegram-bot-webhook
// Failsafe Telegram Bot update handler for session authentication

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const BOT_TOKEN = '8820143653:AAHxNF9bliISyGqEvjzi0Vg3sxDX5C3sW6Q';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'https://qbnzxhiuoxfnxdbpozrx.supabase.co';
const SUPABASE_ANON_KEY =
  Deno.env.get('SUPABASE_ANON_KEY') ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibnp4aGl1b3hmbnhkYnBvenJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMjc2MzEsImV4cCI6MjEwMjcwMzYzMX0.4329lT-YSjE6fuq7maldgDEP7YLShxbd5UNxnpQ3WQg';
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFibnp4aGl1b3hmbnhkYnBvenJ4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NzEyNzYzMSwiZXhwIjoyMTAyNzAzNjMxfQ.AcskVPNlAOaFDAjWpw88nB2m8gueKm3rcbZRsbqOiqY';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { status: 200 });
  }

  try {
    const update = await req.json();
    console.log('Incoming Telegram Update:', JSON.stringify(update));

    const message = update?.message;
    if (!message || !message.text || !message.from) {
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    const text = message.text.trim();
    const from = message.from;
    const chatId = message.chat.id;

    // Check if message is /start auth_...
    if (text.includes('/start auth_')) {
      // Extract sessionId handling possible @BotUsername suffix
      const match = text.match(/\/start\s+(auth_\d+)/);
      const sessionId = match ? match[1] : text.replace('/start', '').trim();

      console.log('Extracted sessionId:', sessionId);

      if (sessionId && sessionId.length > 0) {
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

        const userData = {
          id: from.id,
          first_name: from.first_name || 'مستخدم',
          last_name: from.last_name || null,
          username: from.username || null,
          photo_url: null,
          auth_date: Math.floor(Date.now() / 1000),
          hash: 'bot_auth_verified',
        };

        const { data, error } = await supabase
          .from('auth_sessions')
          .update({
            status: 'completed',
            user_data: userData,
          })
          .eq('id', sessionId)
          .select();

        console.log('Supabase Update Result:', JSON.stringify({ data, error }));

        // Reply to user in Telegram
        await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id: chatId,
            text: `✅ *تم تسجيل الدخول بنجاح!*\n\nأهلاً بك يا ${from.first_name} 👋\nيمكنك العودة إلى تطبيق *قطعه* الآن لتبدأ التدريب! ⚡`,
            parse_mode: 'Markdown',
          }),
        });
      }
    } else if (text.startsWith('/start')) {
      await fetch(`https://api.telegram.org/bot${BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: `مرحباً بك في بوت *قطعه*! ⚡\n\nيرجى فتح التطبيق والضغط على "تسجيل الدخول عبر Telegram" لتسجيل الدخول تلقائياً.`,
          parse_mode: 'Markdown',
        }),
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (err) {
    console.error('Webhook processing error:', err);
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }
});
