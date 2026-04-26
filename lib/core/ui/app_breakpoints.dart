import 'package:responsive_builder/responsive_builder.dart';

enum AppScreenType { mobile, tablet, wideTablet }

AppScreenType appScreenTypeForWidth(double width) {
  if (width >= 1180) {
    return AppScreenType.wideTablet;
  }
  if (width >= 760) {
    return AppScreenType.tablet;
  }
  return AppScreenType.mobile;
}

AppScreenType appScreenTypeFromSizing(SizingInformation sizing) {
  return appScreenTypeForWidth(
    sizing.localWidgetSize.width > 0
        ? sizing.localWidgetSize.width
        : sizing.screenSize.width,
  );
}

bool isPortraitMobileLayout(SizingInformation sizing) {
  final screenType = appScreenTypeFromSizing(sizing);
  return screenType == AppScreenType.mobile &&
      sizing.screenSize.height >= sizing.screenSize.width;
}

double responsiveClampedValue(
  double value, {
  required double min,
  required double max,
}) {
  return value.clamp(min, max).toDouble();
}

double responsiveWidthCap(
  double viewportWidth, {
  required double fraction,
  required double min,
  required double max,
}) {
  return responsiveClampedValue(viewportWidth * fraction, min: min, max: max);
}
