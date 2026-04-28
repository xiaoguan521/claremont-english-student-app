import 'package:flutter/material.dart';

abstract final class AppUiTokens {
  static const Color studentInk = Color(0xFF17335F);
  static const Color studentMuted = Color(0xFF64748B);
  static const Color studentPanel = Color(0xE0FFFFFF);
  static const Color studentPanelBlue = Color(0xFFEAF5FF);
  static const Color studentSuccess = Color(0xFF15803D);
  static const Color studentSuccessSoft = Color(0xFFEAFBF1);
  static const Color studentAccentBlue = Color(0xFF2E7BEF);
  static const Color studentAccentGreen = Color(0xFF72E05B);
  static const Color studentAccentOrange = Color(0xFFFF8F4D);
  static const Color studentAccentPurple = Color(0xFF8B5CF6);
  static const Color studentAccentYellow = Color(0xFFFFD447);
  static const Color studentAvatarBlue = Color(0xFF8EDBFF);
  static const Color studentHeroShadow = Color(0x1F2C84D2);
  static const Color studentTileSoft = Color(0xFFF5FBFF);
  static const Color studentTileBorder = Color(0xFFE0F2FE);

  static const double space2xs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;
  static const double space2xl = 28;
  static const double space3xl = 34;

  static const double radiusSm = 18;
  static const double radiusMd = 22;
  static const double radiusLg = 28;
  static const double radiusXl = 34;
  static const double radiusPill = 999;

  static const double chipHeight = 52;
  static const double iconButtonSize = 42;
  static const int studentPrimaryPaneFlex = 42;
  static const int studentSecondaryPaneFlex = 58;
  static const double studentProfileCompactBreakpoint = 820;
  static const double studentProfileToolCompactBreakpoint = 520;
  static const double studentProfileCompactCardHeight = 430;
  static const double studentProfileCompactToolsHeight = 560;
  static const double studentProfileCompactToolGridHeight = 260;
  static const double studentProfileToolGridHeightFactor = 0.48;
  static const double studentProfileToolGridMinHeight = 220;
  static const double studentProfileToolGridMaxHeight = 300;
  static const double studentProfileToolGridCompactAspectRatio = 1.25;
  static const double studentProfileToolGridAspectRatio = 1.45;
  static const double studentLearningSpaceCompactBreakpoint = 760;
  static const double studentLearningSpaceCompactHeroHeight = 320;
  static const double studentLearningSpaceCompactActionsHeight = 300;
  static const double studentLearningSpaceCompactRoadmapHeight = 520;
  static const double studentLearningSpaceActionGridAspectRatio = 1.42;
  static const double studentSettingsCompactBreakpoint = 920;

  static const EdgeInsets dialogPadding = EdgeInsets.fromLTRB(
    spaceXl,
    spaceXl,
    spaceXl,
    spaceLg,
  );
}
