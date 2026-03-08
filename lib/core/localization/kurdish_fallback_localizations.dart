import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';

class AppMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const AppMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' ||
      locale.languageCode == 'en' ||
      locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    if (locale.languageCode == 'ku') {
      return GlobalMaterialLocalizations.delegate.load(const Locale('ar'));
    }

    return GlobalMaterialLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(AppMaterialLocalizationsDelegate old) => false;
}

class AppCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const AppCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' ||
      locale.languageCode == 'en' ||
      locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    if (locale.languageCode == 'ku') {
      return GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));
    }

    return GlobalCupertinoLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(AppCupertinoLocalizationsDelegate old) => false;
}

class AppWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const AppWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'ar' ||
      locale.languageCode == 'en' ||
      locale.languageCode == 'ku';

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    if (locale.languageCode == 'ku') {
      return GlobalWidgetsLocalizations.delegate.load(const Locale('ar'));
    }

    return GlobalWidgetsLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(AppWidgetsLocalizationsDelegate old) => false;
}
