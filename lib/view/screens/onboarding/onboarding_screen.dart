import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../logic/onboarding/onboarding_provider.dart';
import '../../widgets/onboarding/onboarding_illustration.dart';
import '../../widgets/onboarding/page_indicator.dart';
import '../../widgets/shared/app_logo.dart';
import '../../widgets/shared/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  static const _pageCount = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (mounted) context.go('/login');
  }

  void _next(int currentIndex) {
    if (currentIndex == _pageCount - 1) {
      _complete();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _previous() {
    _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = ref.watch(onboardingPageIndexProvider);
    final isLast = currentIndex == _pageCount - 1;
    final isFirst = currentIndex == 0;

    final pages = [
      _OnboardingSlide(
        illustration: const OnboardingIllustration(
          assetName: 'onboarding_welcome.png',
          fallbackIcon: Icons.menu_book_rounded,
        ),
        title: l10n.onboardingWelcomeTitle,
        brandLine: l10n.appName,
        subtitle: l10n.onboardingWelcomeSubtitlePrefix,
      ),
      _OnboardingSlide(
        illustration: const OnboardingIllustration(
          assetName: 'onboarding_voice.png',
          fallbackIcon: Icons.mic_rounded,
        ),
        title: l10n.onboardingTitle2,
        subtitle: l10n.onboardingBody2,
      ),
      _OnboardingSlide(
        illustration: const OnboardingIllustration(
          assetName: 'onboarding_confirm.png',
          fallbackIcon: Icons.smart_toy_outlined,
        ),
        title: l10n.onboardingTitle3,
        subtitle: l10n.onboardingBody3,
      ),
      _OnboardingSlide(
        illustration: const OnboardingIllustration(
          assetName: 'onboarding_secure.png',
          fallbackIcon: Icons.shield_outlined,
        ),
        title: l10n.onboardingTitle4,
        subtitle: l10n.onboardingBody4,
      ),
    ];

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              const AppLogo(size: 108),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (i) => ref.read(onboardingPageIndexProvider.notifier).state = i,
                  itemBuilder: (context, index) {
                    // Subtle scale+fade parallax as the user swipes between slides — purely
                    // implicit/standard widgets (AnimatedBuilder + Transform + Opacity), no
                    // version-sensitive API.
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        var page = index.toDouble();
                        if (_pageController.hasClients && _pageController.position.haveDimensions) {
                          page = _pageController.page ?? index.toDouble();
                        }
                        final delta = (page - index).clamp(-1.0, 1.0);
                        final scale = 1 - (delta.abs() * 0.08);
                        final opacity = 1 - (delta.abs() * 0.55);
                        return Opacity(
                          opacity: opacity.clamp(0.4, 1.0),
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: pages[index],
                    );
                  },
                ),
              ),
              PageIndicator(count: _pageCount, currentIndex: currentIndex),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    PrimaryButton(
                      label: isLast ? l10n.onboardingStart : l10n.onboardingNext,
                      onPressed: () => _next(currentIndex),
                      leadingIcon: isLast ? null : Icons.arrow_back_ios_new_rounded,
                      variant: isLast ? ButtonVariant.goldFill : ButtonVariant.goldOutline,
                    ),
                    if (!isFirst) ...[
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: l10n.onboardingPrevious,
                        onPressed: _previous,
                        leadingIcon: Icons.arrow_forward_ios_rounded,
                        variant: ButtonVariant.whiteOutline,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared layout per the reference, in this exact order: title (+ optional bold brand line for
/// slide 1) → illustration → subtitle. The subtitle sits BELOW the image, between it and the
/// dots — not above the image.
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.illustration,
    required this.title,
    required this.subtitle,
    this.brandLine,
  });

  final Widget illustration;
  final String title;
  final String? brandLine;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title(context)
                .copyWith(color: AppColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w700),
          ),
          if (brandLine != null) ...[
            const SizedBox(height: 2),
            Text(
              brandLine!,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline(context).copyWith(fontSize: 28, color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: 12),
          illustration,
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context).copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}
