import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Telegram Bot Configuration
const String kTelegramBotToken =
    '8820143653:AAHxNF9bliISyGqEvjzi0Vg3sxDX5C3sW6Q';

/// Telegram Login Widget auth data model
class TelegramUser {
  final int id;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;
  final int authDate;
  final String hash;

  TelegramUser({
    required this.id,
    required this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
    required this.authDate,
    required this.hash,
  });

  factory TelegramUser.fromJson(Map<String, dynamic> json) {
    return TelegramUser(
      id: (json['id'] as num).toInt(),
      firstName: json['first_name'] as String? ?? 'مستخدم',
      lastName: json['last_name'] as String?,
      username: json['username'] as String?,
      photoUrl: json['photo_url'] as String?,
      authDate: (json['auth_date'] as num).toInt(),
      hash: json['hash'] as String? ?? '',
    );
  }

  String get fullName {
    final last = lastName ?? '';
    return last.isEmpty ? firstName : '$firstName $last';
  }

  /// Derived deterministic Supabase credentials from Telegram ID
  /// Email: tg_{id}@qataly.app
  /// Password: HMAC-SHA256 of the telegram ID with a stable app secret
  String get supabaseEmail => 'tg_$id@qataly.app';

  String get supabasePassword {
    const appSecret = 'QatalyTG_2026_Secure_Key_!@#';
    final key = utf8.encode(appSecret);
    final message = utf8.encode('$id');
    final hmac = Hmac(sha256, key);
    return hmac.convert(message).toString();
  }

  /// Verify telegram auth hash to ensure data is not tampered with.
  /// Requires the bot token. In production, do this on a backend/Edge Function.
  /// Here we do a lightweight client-side verification.
  bool verifyHash(String botToken) {
    final dataMap = <String, String>{
      'auth_date': authDate.toString(),
      'first_name': firstName,
      'id': id.toString(),
    };
    if (lastName != null) dataMap['last_name'] = lastName!;
    if (username != null) dataMap['username'] = username!;
    if (photoUrl != null) dataMap['photo_url'] = photoUrl!;

    final dataCheckString = (dataMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}=${e.value}')
        .join('\n');

    // secret = SHA256(bot_token)
    final secretKey = sha256.convert(utf8.encode(botToken)).bytes;
    final hmac = Hmac(sha256, secretKey);
    final expectedHash = hmac.convert(utf8.encode(dataCheckString)).toString();
    return expectedHash == hash;
  }
}

/// HTML page loaded inside WebView to show the Telegram Login Widget.
/// Replace BOT_USERNAME with your actual @BotFather bot username (without @).
String buildTelegramLoginHtml(String botUsername) => '''
<!DOCTYPE html>
<html lang="ar">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Qataly Telegram Login</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #1a0a2e;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      font-family: 'Segoe UI', sans-serif;
    }
    .logo {
      font-size: 42px;
      font-weight: 900;
      color: #ffffff;
      background: #7c3aed;
      padding: 14px 28px;
      border: 3px solid #000;
      box-shadow: 7px 7px 0 #000;
      margin-bottom: 14px;
    }
    .tagline {
      color: #888;
      font-size: 14px;
      margin-bottom: 40px;
      font-style: italic;
    }
    .card {
      background: #12122a;
      border: 2px solid #333;
      border-radius: 4px;
      padding: 32px 28px;
      text-align: center;
      box-shadow: 5px 5px 0 #000;
      max-width: 320px;
    }
    .card h2 { color: #fff; font-size: 20px; margin-bottom: 8px; }
    .card p { color: #aaa; font-size: 13px; margin-bottom: 24px; line-height: 1.5; }
    .tg-wrapper {
      display: flex;
      justify-content: center;
    }
    .loading {
      color: #7c3aed;
      font-size: 13px;
      margin-top: 16px;
    }
  </style>
</head>
<body>
  <div class="logo">قَطْعَلِي ⚡</div>
  <div class="tagline">Adaptive EdTech Engine</div>
  <div class="card">
    <h2>تسجيل الدخول</h2>
    <p>سجّل دخولك باستخدام حساب التليجرام الخاص بك لبدء التدريب على القطع</p>
    <div class="tg-wrapper">
      <script async src="https://telegram.org/js/telegram-widget.js?22"
        data-telegram-login="$botUsername"
        data-size="large"
        data-radius="4"
        data-onauth="onTelegramAuth(user)"
        data-request-access="write">
      </script>
    </div>
    <div class="loading" id="loadingMsg"></div>
  </div>
  <script>
    function onTelegramAuth(user) {
      document.getElementById('loadingMsg').textContent = 'جاري تسجيل الدخول...';
      // Send data to Flutter via JavascriptChannel
      if (window.QatalyTelegramAuth) {
        window.QatalyTelegramAuth.postMessage(JSON.stringify(user));
      }
    }
  </script>
</body>
</html>
''';
