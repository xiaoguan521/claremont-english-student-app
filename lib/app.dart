import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/portal/presentation/widgets/app_sync_queue_listener.dart';
import 'features/school/presentation/widgets/school_link_listener.dart';
import 'shared/widgets/error/error_boundary.dart';
import 'l10n/app_localizations.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeNotifierProvider);
    final eyeComfortEnabled = ref.watch(eyeComfortModeProvider);
    final locale = ref.watch(localeNotifierProvider);

    return ErrorBoundary(
      isRootErrorBoundary: true,
      child: MaterialApp.router(
        title: '英语打卡',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(
          ColorScheme.fromSeed(
            seedColor: themeState.colorSeed.color,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: AppTheme.darkTheme(
          ColorScheme.fromSeed(
            seedColor: themeState.colorSeed.color,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: themeState.themeMode,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: SupportedLocales.locales,
        routerConfig: router,
        builder: (context, child) {
          final appChild = AppSyncQueueListener(
            child: SchoolLinkListener(
              router: router,
              child: child ?? const SizedBox.shrink(),
            ),
          );
          return _EyeComfortScope(enabled: eyeComfortEnabled, child: appChild);
        },
      ),
    );
  }
}

class _EyeComfortScope extends StatelessWidget {
  const _EyeComfortScope({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    final baseTheme = Theme.of(context);
    final comfortTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: Color.alphaBlend(
        const Color(0xFFFFF1C2).withValues(alpha: 0.12),
        baseTheme.scaffoldBackgroundColor,
      ),
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: Color.alphaBlend(
          const Color(0xFFFFF7D6).withValues(alpha: 0.1),
          baseTheme.colorScheme.surface,
        ),
        primary: Color.alphaBlend(
          const Color(0xFF7DBA71).withValues(alpha: 0.12),
          baseTheme.colorScheme.primary,
        ),
      ),
    );

    return Theme(
      data: comfortTheme,
      child: Stack(
        children: [
          child,
          IgnorePointer(
            child: Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFFFF0BD).withValues(alpha: 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
