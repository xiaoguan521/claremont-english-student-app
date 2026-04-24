import 'package:flutter/material.dart';

class BrandAvatar extends StatelessWidget {
  const BrandAvatar({
    required this.logoUrl,
    required this.size,
    required this.borderRadius,
    required this.backgroundColor,
    required this.fallbackIcon,
    required this.fallbackIconColor,
    this.fallbackIconSize,
    super.key,
  });

  final String logoUrl;
  final double size;
  final double borderRadius;
  final Color backgroundColor;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final double? fallbackIconSize;

  bool get _hasLogo => logoUrl.trim().isNotEmpty;

  bool get _isAsset =>
      logoUrl.startsWith('assets/') || logoUrl.startsWith('packages/');

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: !_hasLogo
          ? Icon(
              fallbackIcon,
              color: fallbackIconColor,
              size: fallbackIconSize ?? size * 0.52,
            )
          : _isAsset
          ? Image.asset(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                fallbackIcon,
                color: fallbackIconColor,
                size: fallbackIconSize ?? size * 0.52,
              ),
            )
          : Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                fallbackIcon,
                color: fallbackIconColor,
                size: fallbackIconSize ?? size * 0.52,
              ),
            ),
    );
  }
}
