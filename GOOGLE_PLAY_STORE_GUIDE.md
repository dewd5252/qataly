# 📱 دليل النشر والمراجعة الرسمي لتطبيق «قطعه» (Qata'ly) على Google Play

تم إعداد وتجهيز هذا الدليل لضمان قبول تطبيق **قطعه** على متجر **Google Play** من أول مراجعة ودون أي ملاحظات أو أسباب للرفض.

---

## 1. بيانات دخول المراجعين (App Access Credentials) 🔑

عند تعبئة قسم **App Content -> App Access** في لوحة تحكم **Google Play Console**:
* **الحالة:** اختر **All or some functionality is restricted**.
* **بيانات الحساب التجريبي المعتمد للمراجعين:**
  * **اسم الاعتماد (Credential Name):** `Google Play Reviewer Demo Account`
  * **البريد الإلكتروني (Email / Username):** `demo@qataly.app`
  * **كلمة المرور (Password):** `Qataly@2026`
  * **تعليمات الدخول للمراجع (Instructions for Reviewers):**
    ```text
    1. On the landing/welcome screen, tap "تسجيل الدخول بالبريد الإلكتروني / تجريبي" (or tap the auto-fill demo button).
    2. Enter Email: demo@qataly.app
    3. Enter Password: Qataly@2026
    4. Tap "تسجيل الدخول" to immediately access the student dashboard, interactive AI reading passages, vocabulary weakness tracker, and full learning features.
    ```

> 💡 **ملاحظة:** تم برمجة التطبيق بحيث يمنح هذا البريد صلاحيات وصول كاملة ومستقرة، بينما يتم توجيه أي مستخدم عادي للتسجيل الفوري والآمن عبر تليجرام.

---

## 2. الروابط القانونية وروابط أمان البيانات (Data Safety & Legal URLs) 🌐

جميع هذه الروابط مستضافة كصفحات ويب نقية (Static Web CDN) وتعمل مباشرة عبر HTTPS وسريعة الاستجابة:

| البند | الرابط المباشر (URL) | الاستخدام في Google Play Console |
|---|---|---|
| **سياسة الخصوصية (Privacy Policy)** | `https://dewd5252.github.io/qataly/privacy.html` | يوضع في خانة **Privacy Policy URL** الأساسية للتطبيق |
| **طلب حذف الحساب (Account Deletion)** | `https://dewd5252.github.io/qataly/delete-account.html` | يوضع في استبيان أمان البيانات **Data Safety -> Delete Account URL** |
| **شروط الاستخدام (Terms of Service)** | `https://dewd5252.github.io/qataly/terms.html` | متاح داخل التطبيق والويب للاتفاقيات التعليمية |
| **التراخيص المفتوحة (Open Source)** | `https://dewd5252.github.io/qataly/licenses.html` | تراخيص الحزم والمكتبات |
| **البوابة القانونية الشاملة (Legal Hub)** | `https://dewd5252.github.io/qataly/index.html` | الصفحة المجمعة لكافة الروابط |

---

## 3. سياسة الذكاء الاصطناعي التوليدي (Generative AI Policy) 🤖

* **التوافق:** التطبيق مزود بنظام إبلاغ داخلي كامل (`Report AI Passage`) يظهر كأيقونة علم في الشريط العلوي لشاشة حل التحديات (`challenge_screen.dart`).
* **استبيان تصنيف المحتوى (Content Rating Questionnaire):**
  * عند سؤالك: *Does your app generate content using AI?*
  * الإجابة: **Yes** (محتوى تعليمي وتدريب قراءة للغة الإنجليزية).
  * عند سؤالك: *Does the app provide a mechanism to report offensive AI content?*
  * الإجابة: **Yes** (متاح زر إبلاغ مباشر ومراجعة فورية).

---

## 4. سياسة المدفوعات والاشتراكات (Google Play Billing & Activation Codes) 💳

* أكواد التفعيل في التطبيق مصاغة حصرياً كـ **"أكواد وصول تعليمية وفصول دراسية مقدمة من المعلم أو السنتر"**.
* لا توجد أي روابط أو نصوص داخل التطبيق توجه للدفع الخارجي.

---

## 5. خطوات بناء النسخة النهائية (Release Build) 🚀

1. تأكد من ضبط ملف الـ Keystore والتوقيع في `android/app/build.gradle.kts`.
2. قم بتوليد حزمة المتجر الرسمية (Android App Bundle - `.aab`) عبر تشغيل الأمر:
   ```bash
   flutter build appbundle --release
   ```
3. ستجد الملف الناتج جاهزاً للرفع إلى Google Play Console في المسار:
   `build/app/outputs/bundle/release/app-release.aab`
