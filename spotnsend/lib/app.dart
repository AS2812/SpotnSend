import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'features/home/settings/providers/settings_providers.dart';
import 'l10n/app_localizations.dart';

class SpotnSendApp extends ConsumerWidget {
  const SpotnSendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settingsState = ref.watch(settingsControllerProvider);

    return MaterialApp.router(
      title: 'SpotnSend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settingsState.themeMode,
      locale: settingsState.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Fix yellow text during locale transition
      builder: (context, child) {
        final locale = settingsState.locale;
        final direction = locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr;
        return Directionality(
          textDirection: direction,
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
