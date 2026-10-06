import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

const languages = <String, String>{
  'en-US': 'English',
  'zh-CN': '简体中文',
  'zh-TW': '繁體中文',
  'ja': '日本語',
  'ko': '한국어',
  'ar': 'العربية',
  'fr': 'Français',
  'de': 'Deutsch',
  'es': 'Español',
};

Locale supportedLocale(Locale locale) {
  if (locale.languageCode == 'zh') {
    return locale.scriptCode == 'Hant' ||
            ['TW', 'HK', 'MO'].contains(locale.countryCode)
        ? const Locale('zh', 'TW')
        : const Locale('zh', 'CN');
  }
  return languages.keys.any(
        (tag) => tag.split('-').first == locale.languageCode,
      )
      ? Locale(locale.languageCode)
      : const Locale('en');
}

class AppStrings {
  AppStrings(this.values);
  final Map<String, dynamic> values;
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  String text(String key, [List<Object?> args = const []]) {
    var index = 0;
    return (values[key] as String? ?? key).replaceAllMapped(
      RegExp(r'%(?:(\d+)\$)?[sd]'),
      (match) {
        final position = match[1] == null ? index++ : int.parse(match[1]!) - 1;
        return position < args.length ? '${args[position] ?? ''}' : match[0]!;
      },
    );
  }
}

class StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const StringsDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppStrings> load(Locale locale) async {
    final supported = supportedLocale(locale);
    final tag = supported.languageCode == 'zh'
        ? 'zh-${supported.countryCode}'
        : supported.languageCode;
    return AppStrings(
      jsonDecode(await rootBundle.loadString('assets/i18n/$tag.json'))
          as Map<String, dynamic>,
    );
  }

  @override
  bool shouldReload(StringsDelegate old) => false;
}

extension LocalizedContext on BuildContext {
  String s(String key, [List<Object?> args = const []]) =>
      AppStrings.of(this).text(key, args);
}
