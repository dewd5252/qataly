// Supabase Edge Function: telegram-login
// Serves the Telegram Login Widget HTML from the correct domain.
// Deployed at: https://qbnzxhiuoxfnxdbpozrx.supabase.co/functions/v1/telegram-login

const BOT_USERNAME = 'QatalyBot';

const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>قطعه — تسجيل الدخول</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      height: 100%;
      background: #0A0E27;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #ffffff;
      overflow: hidden;
    }
    .container {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      width: 100%;
      max-width: 360px;
    }
    .brand-title {
      font-size: 40px;
      font-weight: 900;
      color: #ffffff;
      margin-bottom: 6px;
      letter-spacing: 1px;
    }
    .brand-subtitle {
      color: #5B8EE6;
      font-size: 13px;
      margin-bottom: 32px;
      text-align: center;
    }
    .card {
      background: #131B3E;
      border: 2px solid #2A3875;
      border-radius: 16px;
      padding: 32px 24px;
      text-align: center;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
      width: 100%;
    }
    .card h2 {
      color: #ffffff;
      font-size: 20px;
      font-weight: 800;
      margin-bottom: 8px;
    }
    .card p {
      color: #94A3B8;
      font-size: 13px;
      margin-bottom: 24px;
      line-height: 1.5;
    }
    .tg-wrapper {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 48px;
    }
    #status {
      color: #38BDF8;
      font-size: 13px;
      margin-top: 16px;
      font-weight: bold;
      min-height: 20px;
    }
    .credits {
      margin-top: 36px;
      color: #475569;
      font-size: 12px;
      font-weight: 600;
      letter-spacing: 1px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="brand-title">قطعه ⚡</div>
    <div class="brand-subtitle">حل وتدريب على أسئلة قطعة اللغة الإنجليزية</div>

    <div class="card">
      <h2>تسجيل الدخول السريع</h2>
      <p>اضغط على زر التليجرام أدناه للمتابعة والمزامنة</p>
      
      <div class="tg-wrapper">
        <script async
          src="https://telegram.org/js/telegram-widget.js?22"
          data-telegram-login="${BOT_USERNAME}"
          data-size="large"
          data-radius="10"
          data-onauth="onTelegramAuth(user)"
          data-request-access="write">
        </script>
      </div>

      <div id="status"></div>
    </div>

    <div class="credits">— zed32 devs / abo wehidy —</div>
  </div>

  <script>
    function onTelegramAuth(user) {
      document.getElementById('status').textContent = 'تم التوثيق! جاري الدخول... ✈️';
      if (window.QatalyTelegramAuth) {
        window.QatalyTelegramAuth.postMessage(JSON.stringify(user));
      }
    }
  </script>
</body>
</html>`;

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': '*',
      },
    });
  }

  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'X-Content-Type-Options': 'nosniff',
    },
  });
});
