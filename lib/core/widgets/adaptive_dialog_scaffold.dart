import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../ui/app_breakpoints.dart';
import '../ui/app_ui_tokens.dart';

class AdaptiveDialogScaffold extends StatelessWidget {
  const AdaptiveDialogScaffold({
    super.key,
    required this.title,
    required this.bodyBuilder,
    this.trailing = const [],
    this.backgroundColor = const Color(0xFFEAF5FF),
    this.maxDialogWidth = 1320,
    this.maxDialogHeight = 720,
    this.radius = AppUiTokens.radiusXl,
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppUiTokens.spaceXl,
      22,
      AppUiTokens.spaceXl,
      AppUiTokens.spaceXl,
    ),
  });

  final String title;
  final List<Widget> trailing;
  final Color backgroundColor;
  final double maxDialogWidth;
  final double maxDialogHeight;
  final double radius;
  final EdgeInsets contentPadding;
  final Widget Function(
    BuildContext context,
    AppScreenType screenType,
    Size dialogSize,
  )
  bodyBuilder;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizing) {
        final screenType = appScreenTypeFromSizing(sizing);
        final mediaSize = MediaQuery.sizeOf(context);
        final horizontalInset = screenType == AppScreenType.mobile
            ? AppUiTokens.spaceMd
            : AppUiTokens.spaceXl;
        final verticalInset = screenType == AppScreenType.mobile
            ? AppUiTokens.spaceSm
            : AppUiTokens.spaceLg;
        final dialogWidth = math.min(
          maxDialogWidth,
          math.max(320.0, mediaSize.width - horizontalInset * 2),
        );
        final dialogHeight = math.min(
          maxDialogHeight,
          math.max(300.0, mediaSize.height - verticalInset * 2),
        );
        final compact = screenType == AppScreenType.mobile;

        return Dialog(
          backgroundColor: backgroundColor,
          insetPadding: EdgeInsets.symmetric(
            horizontal: horizontalInset,
            vertical: verticalInset,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: dialogHeight,
            ),
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Padding(
                padding: contentPadding,
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.9,
                            ),
                            foregroundColor: const Color(0xFF17335F),
                            minimumSize: Size(
                              compact ? 48 : 58,
                              compact ? 48 : 58,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        SizedBox(
                          width: compact
                              ? AppUiTokens.spaceSm
                              : AppUiTokens.spaceLg - 2,
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: const Color(0xFF17335F),
                                  fontWeight: FontWeight.w900,
                                  fontSize: compact ? 28 : null,
                                ),
                          ),
                        ),
                        ...trailing,
                      ],
                    ),
                    SizedBox(
                      height: compact
                          ? AppUiTokens.spaceSm + 2
                          : AppUiTokens.spaceLg - 2,
                    ),
                    Expanded(
                      child: bodyBuilder(
                        context,
                        screenType,
                        Size(dialogWidth, dialogHeight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
