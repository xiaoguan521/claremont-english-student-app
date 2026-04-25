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
    final locale = ref.watch(localeNotifierProvider);

    return ErrorBoundary(
      isRootErrorBoundary: true,
      child: AppSyncQueueListener(
        child: SchoolLinkListener(
          router: router,
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
          ),
        ),
      ),
    );
  }
}
