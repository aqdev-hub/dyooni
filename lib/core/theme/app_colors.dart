import 'package:flutter/material.dart';

/// Single source of truth for every color used in `view/`.
/// Never hardcode a `Color(0x...)` inside a screen or widget file — add a role here instead.
///
/// Palette v3.1 — deepened navy per direct feedback that v3 read as "faded"/washed out compared
/// to the reference. No light-mode variant exists by design: onboarding/auth are always this
/// dark navy+gold identity regardless of system theme (see main.dart).
abstract class AppColors {
  // Background — deep navy gradient, matching the reference's saturation (not a pale tint of it).
  static const backgroundTop = Color(0xFF091524);
  static const backgroundBottom = Color(0xFF0F2038);

  // Brand
  static const gold = Color(0xFFD9AF62); // logo ring, gold-accented CTA border/fill, active dot
  static const white = Color(0xFFFFFFFF); // secondary ("Previous") button accent

  // Surfaces (cards, input fields, buttons' base fill) — deliberately close to the background so
  // buttons/cards read as "cut into" the navy, not as a lighter gray box floating on top of it.
  static const surface = Color(0xFF122744);
  static const surfaceBorder = Color(0xFF2E4058);

  // Text
  static const textPrimary = Color(0xFFF5F7FA);
  static const textSecondary = Color(0xFFB8C2D2);

  // Semantic — feedback (SnackBars, field errors)
  static const success = Color(0xFF3FA76B);
  static const error = Color(0xFFE0654F);

  // Semantic — debt direction
  static const credit = Color(0xFF3FA76B); // "له" — owed to the user
  static const debit = Color(0xFFE0654F); // "عليه" — owed by the user

  // Soft cell-background tints for the transaction table's amount column — matches the
  // reference's colored amount cells (not just colored text).
  static const creditCell = Color(0xFFDCEFE0);
  static const debitCell = Color(0xFFF6D9D2);

  // Row expand/collapse badge on the accounts list — gold when collapsed, navy when expanded.
  static const chevronCollapsed = gold;
  static const chevronExpanded = backgroundTop;

  // Onboarding page indicator — active dot is gold, inactive is dim.
  static const indicatorActive = gold;
  static const indicatorInactive = Color(0xFF33455F);

  // Voice assistant state ring (Phase 3+) — reserved now so it doesn't collide later
  static const voiceIdle = Color(0xFF8A94A6);
  static const voiceListening = gold;
  static const voiceProcessing = gold;
}
