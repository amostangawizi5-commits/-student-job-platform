import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            title: 'IPTkiganjani',
            debugShowCheckedModeBanner: false,
            locale: languageProvider.locale,
            supportedLocales: LanguageProvider.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              primaryColor: AppTheme.primaryBlue,
              scaffoldBackgroundColor: AppTheme.backgroundLight,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppTheme.primaryBlue,
                primary: AppTheme.primaryBlue,
                surface: AppTheme.white,
                error: AppTheme.error,
              ),
              appBarTheme: AppBarTheme(
                elevation: 0,
                backgroundColor: AppTheme.white,
                foregroundColor: AppTheme.textDark,
                centerTitle: false,
                titleSpacing: 0,
                shadowColor: Colors.transparent,
              ),
              cardTheme: CardThemeData(
                color: AppTheme.cardBg,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                margin: EdgeInsets.zero,
                shadowColor: AppTheme.shadow.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: AppTheme.borderGrey.withValues(alpha: 0.45),
                  ),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: AppTheme.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: AppTheme.borderGrey.withValues(alpha: 0.35),
                  ),
                ),
              ),
              dividerTheme: DividerThemeData(
                color: AppTheme.borderGrey.withValues(alpha: 0.8),
                thickness: 1,
                space: 1,
              ),
              popupMenuTheme: PopupMenuThemeData(
                color: AppTheme.white,
                surfaceTintColor: Colors.transparent,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: AppTheme.borderGrey.withValues(alpha: 0.45),
                  ),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.primaryDark,
                contentTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: AppTheme.white,
                elevation: 12,
                selectedItemColor: AppTheme.primaryBlue,
                unselectedItemColor: AppTheme.textSecondary,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  backgroundColor: AppTheme.white,
                  side: BorderSide(
                    color: AppTheme.borderGrey.withValues(alpha: 0.8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppTheme.surfaceSoft,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: AppTheme.inputBorder(color: Colors.transparent),
                enabledBorder: AppTheme.inputBorder(),
                focusedBorder: AppTheme.inputBorder(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.65),
                  width: 1.4,
                ),
                errorBorder: AppTheme.inputBorder(
                  color: AppTheme.error.withValues(alpha: 0.45),
                ),
                focusedErrorBorder: AppTheme.inputBorder(
                  color: AppTheme.error,
                  width: 1.3,
                ),
              ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
