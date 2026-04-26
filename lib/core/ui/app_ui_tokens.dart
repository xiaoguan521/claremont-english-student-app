import 'package:flutter/material.dart';

abstract final class AppUiTokens {
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

  static const EdgeInsets dialogPadding = EdgeInsets.fromLTRB(
    spaceXl,
    spaceXl,
    spaceXl,
    spaceLg,
  );
}
