import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/localization/kurdish_fallback_localizations.dart';
import 'core/localization/l10n_ext.dart';
import 'core/localization/generated/app_localizations.dart';
import 'shared/providers/app_providers.dart';

class MadaApp extends ConsumerWidget {
  const MadaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    if (bootstrap.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          AppMaterialLocalizationsDelegate(),
          AppCupertinoLocalizationsDelegate(),
          AppWidgetsLocalizationsDelegate(),
        ],
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      l10n.appInitializing,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appInitializingHint,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    if (bootstrap.hasError) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          AppMaterialLocalizationsDelegate(),
          AppCupertinoLocalizationsDelegate(),
          AppWidgetsLocalizationsDelegate(),
        ],
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.appInitFailed,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        AppMaterialLocalizationsDelegate(),
        AppCupertinoLocalizationsDelegate(),
        AppWidgetsLocalizationsDelegate(),
      ],
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: locale.languageCode == 'en'
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}
