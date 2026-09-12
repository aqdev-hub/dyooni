import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/auth/auth_provider.dart';
import '../../widgets/shared/app_logo.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/app_text_field.dart';
import '../../widgets/shared/primary_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _errorMessage(AppLocalizations l10n, Object error) {
    // ignore: avoid_dynamic_calls — AppException is sealed; `code` always exists on this type.
    final code = (error as dynamic).code as String;
    return switch (code) {
      'invalidEmail' => l10n.invalidEmail,
      'emailAlreadyInUse' => l10n.emailAlreadyInUse,
      'passwordTooShort' => l10n.passwordTooShort,
      'passwordsDontMatch' => l10n.passwordsDontMatch,
      'mustAcceptTerms' => l10n.mustAcceptTerms,
      'networkUnreachable' => l10n.networkUnreachable,
      'tooManyRequests' => l10n.tooManyRequests,
      _ => l10n.unexpectedError,
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      AppSnackBar.showError(context, l10n.mustAcceptTerms);
      return;
    }

    await ref.read(signupControllerProvider.notifier).submit(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
          acceptedTerms: _acceptedTerms,
        );

    if (!mounted) return;
    final state = ref.read(signupControllerProvider);
    if (state.hasError) {
      AppSnackBar.showError(context, _errorMessage(l10n, state.error!));
      return;
    }
    AppSnackBar.showSuccess(context, l10n.signupSuccessMessage);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoading = ref.watch(signupControllerProvider).isLoading;

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.topStart,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.textPrimary),
                  onPressed: () => context.go('/login'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 84)),
                        const SizedBox(height: 20),
                        Text(
                          l10n.signupTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headline(context).copyWith(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.signupSubtitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 28),
                        AppTextField(
                          controller: _firstNameController,
                          hint: l10n.firstNameLabel,
                          leadingIcon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _lastNameController,
                          hint: l10n.lastNameLabel,
                          leadingIcon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _emailController,
                          hint: l10n.emailLabel,
                          leadingIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                        ),
                        const SizedBox(height: 14),
                        // TODO(flutter-architect): swap for a real country-code picker package
                        // once target markets are finalized — plain field for now.
                        AppTextField(
                          controller: _phoneController,
                          hint: l10n.phoneLabel,
                          leadingIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _passwordController,
                          hint: l10n.passwordLabel,
                          leadingIcon: Icons.lock_outline_rounded,
                          trailingIcon: _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onTrailingTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          obscureText: _obscurePassword,
                          validator: (v) => (v == null || v.length < 8) ? l10n.passwordTooShort : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _confirmPasswordController,
                          hint: l10n.confirmPasswordLabel,
                          leadingIcon: Icons.lock_outline_rounded,
                          trailingIcon: _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onTrailingTap: () =>
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          obscureText: _obscureConfirmPassword,
                          validator: (v) {
                            if (v == null || v.isEmpty) return l10n.fieldRequired;
                            if (v != _passwordController.text) return l10n.passwordsDontMatch;
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text.rich(
                                  TextSpan(
                                    style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.gold),
                                    children: [
                                      TextSpan(text: l10n.agreeToTermsPrefix),
                                      TextSpan(
                                        text: l10n.termsAndConditions,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      TextSpan(text: l10n.and),
                                      TextSpan(
                                        text: l10n.privacyPolicy,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          label: l10n.signupButton,
                          onPressed: _submit,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: 20),
                        // Same fix as login_screen.dart's bottom row: `Wrap` instead of a plain
                        // `Row`, so "Already have an account?" + "Sign In" can never produce a
                        // RenderFlex overflow in English — it just wraps to a second line if it
                        // ever runs out of horizontal room.
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l10n.haveAccount,
                              style: AppTextStyles.bodySecondary(context).copyWith(color: AppColors.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                l10n.loginButton,
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
            ],
          ),
        ),
      ),
    );
  }
}
