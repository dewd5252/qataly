// Supabase Edge Function: telegram-callback
// Serves HTML with explicit Headers object so Supabase Edge Gateway respects text/html.

Deno.serve(async (req: Request) => {
  const resHeaders = new Headers();
  resHeaders.set('Content-Type', 'text/html; charset=utf-8');
  resHeaders.set('Cache-Control', 'no-store, no-cache, must-revalidate');
  resHeaders.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: resHeaders });
  }

  const html = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>قطعه — جاري فتح التطبيق</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #0A0E27;
      color: #fff;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      text-align: center;
      padding: 24px;
    }
    .spinner {
      width: 56px; height: 56px;
      border: 4px solid #2A3875;
      border-top-color: #229ED9;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin-bottom: 28px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .icon { font-size: 56px; margin-bottom: 16px; display: none; }
    h2 { font-size: 22px; font-weight: 800; margin-bottom: 8px; }
    p { color: #94A3B8; font-size: 14px; margin-bottom: 32px; line-height: 1.6; }
    .btn {
      display: none;
      background: #229ED9;
      color: #fff;
      border: none;
      padding: 16px 36px;
      border-radius: 14px;
      font-size: 16px;
      font-weight: 700;
      cursor: pointer;
      text-decoration: none;
      margin-bottom: 12px;
    }
    .error { color: #F87171; font-size: 13px; display: none; margin-top: 16px; }
    .credits { position: fixed; bottom: 24px; color: #475569; font-size: 12px; }
  </style>
</head>
<body>
  <div class="spinner" id="spinner"></div>
  <div class="icon" id="icon">✅</div>
  <h2 id="title">جاري التحقق...</h2>
  <p id="subtitle">يرجى الانتظار لحظة</p>
  <a class="btn" id="openBtn">افتح تطبيق قطعه ⚡</a>
  <div class="error" id="errorMsg"></div>
  <div class="credits">— zed32 devs / abo wehidy —</div>

  <script>
    function getParam(name) {
      var hash = window.location.hash.substring(1);
      var hashParams = new URLSearchParams(hash);
      var val = hashParams.get(name);
      if (val) return val;
      var queryParams = new URLSearchParams(window.location.search);
      return queryParams.get(name);
    }

    function showError(msg) {
      document.getElementById('spinner').style.display = 'none';
      document.getElementById('icon').style.display = 'block';
      document.getElementById('icon').textContent = '❌';
      document.getElementById('title').textContent = 'فشل التوثيق';
      document.getElementById('subtitle').textContent = msg;
      document.getElementById('errorMsg').style.display = 'block';
      document.getElementById('errorMsg').textContent = msg;
    }

    function openApp(deepLink) {
      document.getElementById('spinner').style.display = 'none';
      document.getElementById('icon').style.display = 'block';
      document.getElementById('title').textContent = 'تم التوثيق بنجاح!';
      document.getElementById('subtitle').textContent = 'جاري فتح تطبيق قطعه تلقائياً...';

      var btn = document.getElementById('openBtn');
      btn.href = deepLink;

      window.location.href = deepLink;

      setTimeout(function() {
        btn.style.display = 'inline-block';
        document.getElementById('subtitle').textContent = 'اضغط الزر أدناه إذا لم يفتح التطبيق تلقائياً';
      }, 3000);
    }

    var tgAuthResult = getParam('tgAuthResult');
    if (tgAuthResult && tgAuthResult.length > 0) {
      var deepLink = 'qataly://auth?tgAuthResult=' + encodeURIComponent(tgAuthResult);
      openApp(deepLink);
    } else {
      setTimeout(function() {
        var result = getParam('tgAuthResult');
        if (result) {
          var deepLink = 'qataly://auth?tgAuthResult=' + encodeURIComponent(result);
          openApp(deepLink);
        } else {
          showError('لم يتم استلام بيانات التوثيق. حاول مرة أخرى.');
        }
      }, 500);
    }
  </script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: resHeaders,
  });
});
