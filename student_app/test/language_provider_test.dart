import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider', () {
    test('loads a saved language from preferences', () async {
      SharedPreferences.setMockInitialValues({'app_language_code': 'sw'});
      final preferences = await SharedPreferences.getInstance();

      final provider = LanguageProvider(
        preferencesLoader: () async => preferences,
      );

      await Future<void>.delayed(Duration.zero);

      expect(provider.localeCode, 'sw');
      expect(provider.selectedLanguageName, 'Kiswahili');
      expect(provider.tr('change_language'), 'Badili lugha');
    });

    test('updates locale and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final provider = LanguageProvider(
        preferencesLoader: () async => preferences,
      );

      await provider.setLocaleCode('sw');

      expect(provider.localeCode, 'sw');
      expect(provider.selectedLanguageName, 'Kiswahili');
      expect(preferences.getString('app_language_code'), 'sw');
      expect(
        provider.tr('language_changed_to', {'language': 'Kiswahili'}),
        'Lugha imebadilishwa kuwa Kiswahili',
      );
    });

    test(
      'ignores unsupported language codes including removed French',
      () async {
        SharedPreferences.setMockInitialValues({'app_language_code': 'en'});
        final preferences = await SharedPreferences.getInstance();
        final provider = LanguageProvider(
          preferencesLoader: () async => preferences,
        );

        await provider.setLocaleCode('fr');

        expect(provider.localeCode, 'en');
        expect(preferences.getString('app_language_code'), 'en');
      },
    );
  });
}
