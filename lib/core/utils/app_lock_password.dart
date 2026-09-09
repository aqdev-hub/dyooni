import 'dart:convert';
import 'package:crypto/crypto.dart';

/// تجزئة أحادية الاتجاه لكلمة مرور قفل التطبيق — لا تُخزَّن كلمة المرور الخام أبدًا على القرص،
/// فقط ناتج SHA-256 لها. نفس فلسفة عدم تخزين الأسرار الخام المتّبعة في
/// core/utils/backup_crypto.dart، لكن أبسط عمدًا: هذا قفل واجهة محلي (ليس تشفير بيانات كامل)،
/// فلا حاجة لملح/IV عشوائيين — القيمة المخزَّنة لا تُقارَن إلا بنفسها.
String hashAppLockPassword(String rawPassword) =>
    sha256.convert(utf8.encode('dyooni_app_lock::$rawPassword')).toString();
