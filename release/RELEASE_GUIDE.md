# دليل إصدار نسخة جديدة من ديوني

## مرة واحدة فقط (الإعداد)
1. **انشر قواعد Firestore** (فيها السماح بقراءة `app_config`):
   - إما `firebase deploy --only firestore:rules` من مجلد المشروع،
   - أو انسخ محتوى `firestore.rules` إلى Firebase Console ← Firestore Database ← Rules ← Publish.
2. **أنشئ المستند**: Firebase Console ← Firestore Database ← Start collection
   - Collection ID: `app_config`
   - Document ID: `release`
   - أضف الحقول من `release/firestore_release_doc.json` (النوع: `version` و`url` نص، `build` و`minSupportedBuild` رقم، `notes_ar` و`notes_en` مصفوفة نصوص).

## في كل إصدار جديد
1. ارفع رقم الإصدار في **ثلاثة أماكن بنفس القيمة**: `pubspec.yaml` (`version: 0.2.0+2`)، و`lib/core/utils/app_version.dart` (`kAppVersion`). الرقم بعد `+` هو رقم البناء ويجب أن يزيد في كل إصدار (Google Play يرفض الأقل أو المساوي).
2. شغّل `flutter analyze` و`flutter test`.
3. ابنِ: `flutter build appbundle --release` ثم ارفع الملف في Play Console (وانسخ نص «ما الجديد» من ملف الملاحظات).
4. **بعد أن يصبح الإصدار متاحًا في المتجر** (وليس قبله) عدّل مستند `app_config/release`: `version` و`build` والملاحظات و`url`. بمجرد حفظه يرى المستخدمون النافذة (عند فتح التطبيق مرة يوميًا، أو فورًا من «حول التطبيق ← البحث عن تحديث»).

## تحديث إلزامي
ضع في `minSupportedBuild` رقم أول بناء تقبله. من كان بناؤه أقل يرى نافذة لا تُغلق وزر «تحديث الآن» فقط.

## ملاحظات
- المقارنة تتم برقم البناء فقط، فلا تُعدّل `build` إلى رقم أصغر.
- إذا حذفت المستند أو أخطأت في نوع حقل، يظهر للمستخدم «تعذّر فحص التحديثات» ولا تظهر نافذة خاطئة.
- بعد النشر في المتجر ضع في `AppLinks.playStoreUrl` رابط المتجر، وحدّث `url` في المستند.
