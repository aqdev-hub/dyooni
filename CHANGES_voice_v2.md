# تغييرات النظام الصوتي (الدفعة الثانية — تشمل الدفعة الأولى)

- lib/logic/voice/arabic_number_parser.dart (جديد): محرك الأرقام العربية المنطوقة.
- lib/logic/voice/voice_command_parser.dart: استخدام المحرك، استخراج الاسم من التوكنات، amountUncertain.
- lib/logic/voice/voice_provider.dart: تسلسل الأسئلة، هل هو نفس الحساب، التعديل المباشر، الإلغاء الفوري، بدائل السحابة.
- lib/core/voice/*: errors/lastAlternatives، كتم أصوات النظام، إيقاف echoCancel/noiseSuppress في Vosk.
- android/.../MainActivity.kt: قناة كتم النغمات.
- lib/core/theme/voice_palette.dart (جديد) + main_bottom_nav.dart + voice_command_screen.dart + voice_command_sheet.dart: الواجهة.
- lib/core/l10n/app_ar.arb / app_en.arb / generated/*: نصوص جديدة.
- test/logic/voice/*: اختبارات.
