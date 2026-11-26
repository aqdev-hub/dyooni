import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shell_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../logic/auth/auth_provider.dart';
import '../../../logic/settings/general_settings_provider.dart';
import '../../widgets/shared/app_logo.dart';
import '../../widgets/shared/app_snackbar.dart';

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

class _AppLockScreenState extends ConsumerState<AppLockScreen> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _biometricTried = false;
  bool _biometricFailed = false;

  // Wrong tries made with the button / keyboard "done" (typing a number never counts — it is
  // checked silently on every keystroke). Five misses pause the button for 30 s.
  int _failedAttempts = 0;
  DateTime? _blockedUntil;

  // «نسيت كلمة المرور؟» is an inline panel, not a dialog: this screen is built ABOVE the app's
  // Navigator (MaterialApp.router builder), where showDialog has no Navigator to use.
  bool _resetting = false;
  bool _resetBusy = false;
  final _accountPasswordController = TextEditingController();

  // A short horizontal shake + a red line tell the person a full-length entry was wrong.
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _showWrong = false;

  bool get _isBlocked {
    final b = _blockedUntil;
    return b != null && DateTime.now().isBefore(b);
  }

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

  void _clearField() => _controller.value = TextEditingValue.empty;

  /// Counts a miss; five misses pause entry for 30 s. Shared by typing and the button so neither
  /// path can be used to guess without limit.
  void _registerMiss(AppLocalizations l10n) {
    HapticFeedback.heavyImpact();
    _failedAttempts++;
    if (_failedAttempts >= 5) {
      _failedAttempts = 0;
      _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
      AppSnackBar.showError(context, l10n.appLockTooManyAttempts);
    }
    _clearField();
    unawaited(_shake.forward(from: 0));
    setState(() => _showWrong = true);
  }

  void _unlock(int length) {
    // Old settings do not carry the length yet: learn it now so the next unlock is automatic.
    unawaited(ref.read(generalSettingsProvider.notifier).rememberPasswordLength(length));
    widget.onUnlocked();
  }

  /// Runs on every keystroke. The length is known (stored when the password was set), so:
  ///  * the moment the typed length equals it the entry is checked — right → unlocked at once, no
  ///    button; wrong → shake + message + field cleared, and a longer entry is impossible
  ///    (the field is capped at that length);
  ///  * old settings without a stored length are checked silently on every keystroke instead.
  void _onPasswordChanged(String value) {
    if (_showWrong && value.isNotEmpty) setState(() => _showWrong = false);
    if (value.isEmpty) return;
    if (_isBlocked) {
      _clearField();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(generalSettingsProvider.notifier);
    final length = ref.read(generalSettingsProvider).value?.passwordLength;
    if (length == null) {
      if (notifier.verifyPassword(value)) _unlock(value.length);
      return;
    }
    if (value.length < length) return;
    if (notifier.verifyPassword(value)) {
      _unlock(length);
    } else {
      _registerMiss(l10n);
    }
  }

  void _attemptLogin() {
    final l10n = AppLocalizations.of(context)!;
    if (_isBlocked) {
      AppSnackBar.showError(context, l10n.appLockTooManyAttempts);
      return;
    }
    final text = _controller.text;
    if (ref.read(generalSettingsProvider.notifier).verifyPassword(text)) {
      _unlock(text.length);
      return;
    }
    _registerMiss(l10n);
  }

  /// Proves the person owns the signed-in Dyooni account (see AuthRepository.reauthenticate) and
  /// only then removes the local lock password. The lock is a local convenience lock, so the
  /// account is the right proof of ownership — never a bypass without one.
  Future<void> _resetLock() async {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.read(authProfileProvider);
    if (profile == null) {
      AppSnackBar.showError(context, l10n.appLockResetFailed);
      return;
    }
    setState(() => _resetBusy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .reauthenticate(password: profile.usesPassword ? _accountPasswordController.text : null);
      await ref.read(generalSettingsProvider.notifier).disablePassword();
      if (!mounted) return;
      AppSnackBar.showSuccess(context, l10n.appLockResetDone);
      widget.onUnlocked();
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_dynamic_calls
      final code = (e as dynamic).code as String?;
      if (code != 'cancelled') AppSnackBar.showError(context, l10n.appLockResetFailed);
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  Widget _resetPanel(AppLocalizations l10n, AppShellColors shell) {
    final usesPassword = ref.watch(authProfileProvider)?.usesPassword ?? true;
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.appLockResetTitle,
            style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            usesPassword ? l10n.appLockResetBodyPassword : l10n.appLockResetBodySocial,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (usesPassword)
            TextField(
              controller: _accountPasswordController,
              obscureText: true,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(color: shell.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.appLockResetPasswordHint,
                hintStyle: TextStyle(color: shell.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: shell.accent)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: shell.accent, width: 2)),
              ),
              onSubmitted: (_) {
                if (!_resetBusy) unawaited(_resetLock());
              },
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetBusy ? null : () => unawaited(_resetLock()),
            style: ElevatedButton.styleFrom(
              backgroundColor: shell.accent,
              foregroundColor: shell.headerBottom,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _resetBusy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.appLockResetConfirm, style: AppTextStyles.button(context).copyWith(color: shell.headerBottom, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: _resetBusy ? null : () => setState(() => _resetting = false),
            child: Text(l10n.cancel, style: TextStyle(color: shell.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _shake.dispose();
    _accountPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shell = context.shellColors;
    final settings = ref.watch(generalSettingsProvider).value;
    final passwordEnabled = settings?.passwordEnabled ?? false;
    final biometricEnabled = settings?.biometricEnabled ?? false;
    final passwordLength = settings?.passwordLength;

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
                  if (_resetting)
                    _resetPanel(l10n, shell)
                  else if (passwordEnabled) ...[
                    Text(
                      biometricEnabled ? l10n.appLockEnterPasswordOrBiometric : l10n.appLockEnterPasswordOnly,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary(context).copyWith(color: shell.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _shake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
                        child: child,
                      ),
                      child: SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _controller,
                          obscureText: true,
                          autofocus: !biometricEnabled,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.center,
                          // Never let the keyboard suggest / autofill an earlier (wrong) entry.
                          enableSuggestions: false,
                          autocorrect: false,
                          enableIMEPersonalizedLearning: false,
                          autofillHints: null,
                          inputFormatters: [
                            if (passwordLength != null) LengthLimitingTextInputFormatter(passwordLength),
                          ],
                          style: AppTextStyles.title(context).copyWith(color: shell.textPrimary, letterSpacing: 8),
                          decoration: InputDecoration(
                            counterText: '',
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: _showWrong ? AppColors.error : shell.accent)),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: _showWrong ? AppColors.error : shell.accent, width: 2)),
                          ),
                          onChanged: _onPasswordChanged,
                          onSubmitted: (_) => _attemptLogin(),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 22,
                      child: _showWrong
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                l10n.appLockWrongPasswordMessage,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.error, fontSize: 12),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton(
                        onPressed: _attemptLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: shell.accent,
                          foregroundColor: shell.headerBottom,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          l10n.appLockLoginButton,
                          style: AppTextStyles.button(context).copyWith(color: shell.headerBottom, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _resetting = true),
                      child: Text(l10n.appLockForgot, style: TextStyle(color: shell.accent, fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (biometricEnabled && !_resetting) ...[
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
