import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/providers/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rebuilds dependent widgets after changing the locale', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final languageProvider = LanguageProvider(
      preferencesLoader: () async => preferences,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>.value(
        value: languageProvider,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<LanguageProvider>(
              builder: (context, language, _) {
                return Text(language.tr('change_language'));
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Change language'), findsOneWidget);

    await languageProvider.setLocaleCode('sw');
    await tester.pump();

    expect(find.text('Badili lugha'), findsOneWidget);
  });
}
