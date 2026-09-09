import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../../widgets/shared/app_logo.dart';

/// شاشة قفل حقيقية — تُعرض فوق كل شيء عبر `MaterialApp.router`'s `builder:` (انظر main.dart)
/// كلما كانت الحماية بكلمة مرور و/أو بالبصمة مفعّلة ولم يفتح المستخدم التطبيق بعد لهذه الجلسة.
///
/// الفتح بكلمة المرور فوري بمجرد تطابقها (بلا زر تأكيد)، والفتح بالبصمة يُحاوَل تلقائيًا عند
/// ظهور الشاشة إن كانت مفعّلة. كل نص هنا يمر عبر core/l10n، وكل لون يأتي من AppShellColors/
/// AppColors الموجودين أصلًا في المشروع — لا نصوص ولا ألوان مكتوبة مباشرة.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({required this.onUnlocked, super.key});
  final VoidCallback onUnlocked;

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _controller = TextEditingController();
  bool _biometricTried = false;
  bool _biometricFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_biometricTried) return;
    final settings = ref.read(generalSettingsProvider).value;
    if (settings == null || !settings.biometricEnabled) return;
    _biometricTried = true;
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref.read(biometricAuthServiceProvider).authenticate(reason: l10n.appLockBiometricReason);
    if (ok) {
      widget.onUnlocked();
    } else if (mounted) {
      setState(() => _biometricFailed = true);
    }
  }

  void _onPasswordChanged(String value) {
    // فتح فوري بمجرد صحة كلمة المرور — بلا زر تأكيد، تمامًا كما طُلب.
    final ok = ref.read(generalSettingsProvider.notifier).verifyPassword(value);
    if (ok) widget.onUnlocked();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final settings = ref.watch(generalSettingsProvider).value;
    final passwordEnabled = settings?.passwordEnabled ?? false;
    final biometricEnabled = settings?.biometricEnabled ?? false;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: shell.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 88),
                  const SizedBox(height: 20),
                  Icon(Icons.lock_outline_rounded, color: shell.accent, size: 34),
                  const SizedBox(height: 6),
                  Text(
                    l10n.appLockTitle,
                    style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 17),
                  ),
                  const SizedBox(height: 24),
                  if (passwordEnabled) ...[
                    Text(
                      biometricEnabled ? l10n.appLockEnterPasswordOrBiometric : l10n.appLockEnterPasswordOnly,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _controller,
                        obscureText: true,
                        autofocus: !biometricEnabled,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, letterSpacing: 8),
                        decoration: InputDecoration(
                          border: UnderlineInputBorder(borderSide: BorderSide(color: shell.accent)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: shell.accent, width: 2)),
                        ),
                        onChanged: _onPasswordChanged,
                      ),
                    ),
                  ],
                  if (biometricEnabled) ...[
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () {
                        setState(() => _biometricFailed = false);
                        _biometricTried = false;
                        _tryBiometric();
                      },
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: shell.surface,
                          border: Border.all(color: shell.accent, width: 1.4),
                        ),
                        child: Icon(Icons.fingerprint_rounded, color: shell.accent, size: 38),
                      ),
                    ),
                    if (_biometricFailed) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.appLockBiometricFailed,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error, fontSize: 12),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
