import 'package:flutter/material.dart';

/// Colors of the voice screen (reference design, stages 1–5). Kept as a role-based palette —
/// never as literals inside widgets — with a light set (sampled from the approved reference
/// image) and a dark set that keeps the same roles readable in dark mode.
class VoicePalette {
  const VoicePalette({
    required this.bodyTop,
    required this.bodyBottom,
    required this.wave,
    required this.headerGold,
    required this.textPrimary,
    required this.textSecondary,
    required this.gold,
    required this.goldSoft,
    required this.goldGlow,
    required this.goldButtonTop,
    required this.goldButtonBottom,
    required this.goldDeepTop,
    required this.goldDeepBottom,
    required this.micTop,
    required this.micBottom,
    required this.card,
    required this.cardShadow,
    required this.pillBorder,
    required this.tipBackground,
    required this.tipBorder,
    required this.questionBackground,
    required this.questionBorder,
    required this.summaryBackground,
    required this.summaryBorder,
    required this.success,
    required this.stopRed,
    required this.stopGlow,
    required this.navBackground,
    required this.onGold,
  });

  final Color bodyTop;
  final Color bodyBottom;
  final Color wave;
  final Color headerGold;
  final Color textPrimary;
  final Color textSecondary;
  final Color gold;
  final Color goldSoft;
  final Color goldGlow;
  final Color goldButtonTop;
  final Color goldButtonBottom;
  final Color goldDeepTop;
  final Color goldDeepBottom;
  final Color micTop;
  final Color micBottom;
  final Color card;
  final Color cardShadow;
  final Color pillBorder;
  final Color tipBackground;
  final Color tipBorder;
  final Color questionBackground;
  final Color questionBorder;
  final Color summaryBackground;
  final Color summaryBorder;
  final Color success;
  final Color stopRed;
  final Color stopGlow;
  final Color navBackground;
  final Color onGold;

  static const light = VoicePalette(
    bodyTop: Color(0xFFF8FBFF),
    bodyBottom: Color(0xFFE4F0FA),
    wave: Color(0xFFCFE4F6),
    headerGold: Color(0xFFF3BF22),
    textPrimary: Color(0xFF0A2247),
    textSecondary: Color(0xFF1D3C6B),
    gold: Color(0xFFF1B922),
    goldSoft: Color(0xFFFBE7A6),
    goldGlow: Color(0xFFFBF0C8),
    goldButtonTop: Color(0xFFF0C04A),
    goldButtonBottom: Color(0xFFDDA02F),
    goldDeepTop: Color(0xFFD9A93F),
    goldDeepBottom: Color(0xFFBD871B),
    micTop: Color(0xFF0F3A70),
    micBottom: Color(0xFF052247),
    card: Color(0xFFFFFFFF),
    cardShadow: Color(0x1A0A2247),
    pillBorder: Color(0xFFF0DDA6),
    tipBackground: Color(0xFFEAF4FD),
    tipBorder: Color(0xFFCFE3F5),
    questionBackground: Color(0xFFE9F3FC),
    questionBorder: Color(0xFFCBE0F4),
    summaryBackground: Color(0xFFFFFDF6),
    summaryBorder: Color(0xFFF2DFAE),
    success: Color(0xFF0F9D4B),
    stopRed: Color(0xFFE0302B),
    stopGlow: Color(0xFFF9C7C3),
    navBackground: Color(0xFF022345),
    onGold: Color(0xFFFFFFFF),
  );

  static const dark = VoicePalette(
    bodyTop: Color(0xFF0B1424),
    bodyBottom: Color(0xFF0E1D33),
    wave: Color(0xFF14284A),
    headerGold: Color(0xFFFDC02D),
    textPrimary: Color(0xFFF3F5F8),
    textSecondary: Color(0xFFB5BECD),
    gold: Color(0xFFFDC02D),
    goldSoft: Color(0xFF6B5420),
    goldGlow: Color(0xFF2A2A2A),
    goldButtonTop: Color(0xFFF0C04A),
    goldButtonBottom: Color(0xFFDDA02F),
    goldDeepTop: Color(0xFFD9A93F),
    goldDeepBottom: Color(0xFFBD871B),
    micTop: Color(0xFF173F75),
    micBottom: Color(0xFF071B38),
    card: Color(0xFF121A29),
    cardShadow: Color(0x33000000),
    pillBorder: Color(0xFF5A4A22),
    tipBackground: Color(0xFF11233B),
    tipBorder: Color(0xFF28415F),
    questionBackground: Color(0xFF11233B),
    questionBorder: Color(0xFF28415F),
    summaryBackground: Color(0xFF17171F),
    summaryBorder: Color(0xFF5A4A22),
    success: Color(0xFF2FBF6B),
    stopRed: Color(0xFFE0302B),
    stopGlow: Color(0xFF5A2320),
    navBackground: Color(0xFF071C31),
    onGold: Color(0xFFFFFFFF),
  );
}

extension VoicePaletteX on BuildContext {
  VoicePalette get voicePalette =>
      Theme.of(this).brightness == Brightness.dark ? VoicePalette.dark : VoicePalette.light;
}
