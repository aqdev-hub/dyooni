import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/auth/auth_provider.dart';
import '../../widgets/auth/social_login_button.dart';
import '../../widgets/shared/app_logo.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/app_text_field.dart';
import '../../widgets/shared/language_toggle_button.dart';
import '../../widgets/shared/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _errorMessage(AppLocalizations l10n, Object error) {
    // AppException is a sealed class (see core/utils/app_exception.dart) — every member has
    // `code`, so this dynamic access is safe for every value this provider can produce.
    // ignore: avoid_dynamic_calls
    final code = (error as dynamic).code as String;
    return switch (code) {
      'invalidEmail' => l10n.invalidEmail,
      'invalidCredentials' => l10n.invalidCredentials,
      'userNotFound' => l10n.userNotFound,
      'userDisabled' => l10n.userDisabled,
      'tooManyRequests' => l10n.tooManyRequests,
      'networkUnreachable' => l10n.networkUnreachable,
      _ => l10n.unexpectedError,
    };
  }

  Future<void> _afterSubmit(AppLocalizations l10n) async {
    final state = ref.read(loginControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      AppSnackBar.showError(context, _errorMessage(l10n, state.error!));
      return;
    }
    AppSnackBar.showSuccess(context, l10n.loginSuccessMessage);
    context.go('/home');
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    await ref.read(loginControllerProvider.notifier).submit(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
    await _afterSubmit(l10n);
  }

  Future<void> _submitWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(loginControllerProvider.notifier).submitWithGoogle();
    await _afterSubmit(l10n);
  }

  Future<void> _submitWithFacebook() async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(loginControllerProvider.notifier).submitWithFacebook();
    await _afterSubmit(l10n);
  }

  Future<void> _showForgotPasswordDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final emailController = TextEditingController(text: _identifierController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.forgotPasswordDialogTitle, style: AppTextStyles.title(dialogContext)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.forgotPasswordDialogBody,
              style: AppTextStyles.bodySecondary(dialogContext).copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: emailController,
              hint: l10n.emailLabel,
              leadingIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(emailController.text.trim()),
            child: Text(l10n.sendResetLink, style: const TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !mounted) return;
    await ref.read(loginControllerProvider.notifier).sendPasswordResetEmail(email);
    if (!mounted) return;
    final state = ref.read(loginControllerProvider);
    if (state.hasError) {
      AppSnackBar.showError(context, _errorMessage(l10n, state.error!));
    } else {
      AppSnackBar.showSuccess(context, l10n.forgotPasswordEmailSentMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = ref.watch(loginControllerProvider).isLoading;

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageToggleButton()),
                  const SizedBox(height: 4),
                  const Center(child: AppLogo(size: 88)),
                  const SizedBox(height: 20),
                  Text(
                    l10n.loginWelcomeTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headline(context).copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  AppTextField(
                    controller: _identifierController,
                    hint: l10n.loginIdentifierLabel,
                    leadingIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _passwordController,
                    hint: l10n.passwordLabel,
                    leadingIcon: Icons.lock_outline_rounded,
                    trailingIcon:
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    onTrailingTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    obscureText: _obscurePassword,
                    validator: (v) => (v == null || v.isEmpty) ? l10n.fieldRequired : null,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        l10n.forgotPassword,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: l10n.loginButton,
                    onPressed: _submit,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          l10n.orLoginWith,
                          style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SocialLoginButton(
                          provider: SocialProvider.google,
                          onPressed: isLoading ? null : _submitWithGoogle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SocialLoginButton(
                          provider: SocialProvider.facebook,
                          onPressed: isLoading ? null : _submitWithFacebook,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Was a plain `Row` with no Expanded/Flexible — that's exactly what overflowed
                  // in English ("Don't have an account?" + "Create a new account" together are
                  // wider than the screen once you add the TextButton's own default padding).
                  // `Wrap` can never overflow this way: if the two pieces don't fit on one line,
                  // it drops the button to its own line instead of breaching the screen edge.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.noAccount,
                        style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => context.go('/signup'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.createAccount,
                          style: AppTextStyles.bodySecondary(context)
                              .copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
