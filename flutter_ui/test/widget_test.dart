import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/strings.dart';
import 'package:flutter/widgets.dart';

void main() {
  test(
    'unsupported languages use English; traditional Chinese stays traditional',
    () {
      expect(supportedLocale(const Locale('it')).languageCode, 'en');
      expect(supportedLocale(const Locale('zh', 'HK')).countryCode, 'TW');
      expect(
        supportedLocale(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ).countryCode,
        'TW',
      );
    },
  );
}
