import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  LanguageProvider() {
    _loadSavedLanguage();
  }

  static const String _storageKey = 'app_language_code';
  static const List<Locale> supportedLocales = [Locale('en'), Locale('sw')];

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'dashboard': 'Dashboard',
      'search': 'Search',
      'users': 'Users',
      'jobs': 'Jobs',
      'applications': 'Applications',
      'home': 'Home',
      'apps': 'Apps',
      'browse': 'Browse',
      'my_apps': 'My Apps',
      'my_jobs': 'My Jobs',
      'profile': 'Profile',
      'settings': 'Settings',
      'change_language': 'Change language',
      'change_language_title': 'Change Language',
      'language': 'Language',
      'logout': 'Logout',
      'cancel': 'Cancel',
      'apply': 'Apply',
      'notifications': 'Notifications',
      'admin_settings': 'Admin Settings',
      'student_settings': 'Student Settings',
      'company_settings': 'Company Settings',
      'open_admin_notifications': 'Open admin notifications',
      'open_your_notifications': 'Open your notifications',
      'open_company_notifications': 'Open company notifications',
      'refresh_unread_count': 'Refresh unread count',
      'sync_latest_notification_badge': 'Sync the latest notification badge',
      'my_applications': 'My Applications',
      'open_applications_tab': 'Open applications tab',
      'company_profile': 'Company Profile',
      'open_profile_tab': 'Open profile tab',
      'logout_title': 'Logout',
      'logout_confirm': 'Are you sure you want to logout?',
      'logout_success': 'Logout successful!',
      'language_changed_to': 'Language changed to {language}',
      'admin_panel_date': 'Admin Panel • {date}',
      'company_dashboard': 'Company Dashboard',
      'government_system': 'Government System',
      'more_actions': 'More actions',
      'hello_name': 'Hello, {name}!',
      'student': 'Student',
      'company': 'Company',
      'search_companies_jobs_hint': 'Search companies or jobs',
      'search_admin_subtitle':
          'Find companies and jobs quickly from one place.',
      'search_companies': 'Companies',
      'search_jobs': 'Jobs',
      'open_users_tab': 'Open users tab',
      'open_jobs_tab': 'Open jobs tab',
      'start_search_message': 'Start typing to search for a company or a job.',
      'no_search_results': 'No matching companies or jobs found.',
      'search_results_count': '{count} result(s)',
      'industry_label': 'Industry: {value}',
      'location_label': 'Location: {value}',
      'email_label': 'Email: {value}',
      'company_label': 'Company: {value}',
    },
    'sw': {
      'dashboard': 'Dashibodi',
      'search': 'Tafuta',
      'users': 'Watumiaji',
      'jobs': 'Kazi',
      'applications': 'Maombi',
      'home': 'Nyumbani',
      'apps': 'Appu',
      'browse': 'Tafuta',
      'my_apps': 'Maombi Yangu',
      'my_jobs': 'Kazi Zangu',
      'profile': 'Wasifu',
      'settings': 'Mipangilio',
      'change_language': 'Badili lugha',
      'change_language_title': 'Badili Lugha',
      'language': 'Lugha',
      'logout': 'Toka',
      'cancel': 'Ghairi',
      'apply': 'Tumia',
      'notifications': 'Arifa',
      'admin_settings': 'Mipangilio ya Admin',
      'student_settings': 'Mipangilio ya Mwanafunzi',
      'company_settings': 'Mipangilio ya Kampuni',
      'open_admin_notifications': 'Fungua arifa za admin',
      'open_your_notifications': 'Fungua arifa zako',
      'open_company_notifications': 'Fungua arifa za kampuni',
      'refresh_unread_count': 'Sasisha idadi ya arifa',
      'sync_latest_notification_badge': 'Leta alama ya arifa mpya',
      'my_applications': 'Maombi Yangu',
      'open_applications_tab': 'Fungua ukurasa wa maombi',
      'company_profile': 'Wasifu wa Kampuni',
      'open_profile_tab': 'Fungua ukurasa wa wasifu',
      'logout_title': 'Toka',
      'logout_confirm': 'Una uhakika unataka kutoka?',
      'logout_success': 'Umetoka kwa mafanikio!',
      'language_changed_to': 'Lugha imebadilishwa kuwa {language}',
      'admin_panel_date': 'Paneli ya Admin • {date}',
      'company_dashboard': 'Dashibodi ya Kampuni',
      'government_system': 'Mfumo wa Serikali',
      'more_actions': 'Vitendo zaidi',
      'hello_name': 'Habari, {name}!',
      'student': 'Mwanafunzi',
      'company': 'Kampuni',
      'search_companies_jobs_hint': 'Tafuta kampuni au kazi',
      'search_admin_subtitle':
          'Pata kampuni na kazi kwa haraka kutoka sehemu moja.',
      'search_companies': 'Kampuni',
      'search_jobs': 'Kazi',
      'open_users_tab': 'Fungua ukurasa wa watumiaji',
      'open_jobs_tab': 'Fungua ukurasa wa kazi',
      'start_search_message': 'Anza kuandika kutafuta kampuni au kazi.',
      'no_search_results': 'Hakuna kampuni au kazi iliyopatikana.',
      'search_results_count': 'Matokeo {count}',
      'industry_label': 'Sekta: {value}',
      'location_label': 'Mahali: {value}',
      'email_label': 'Barua pepe: {value}',
      'company_label': 'Kampuni: {value}',
    },
  };

  String _localeCode = 'en';

  String get localeCode => _localeCode;
  Locale get locale => Locale(_localeCode);
  String get selectedLanguageName => nativeLanguageName(_localeCode);

  Future<void> _loadSavedLanguage() async {
    final preferences = await SharedPreferences.getInstance();
    final savedCode = preferences.getString(_storageKey);
    if (savedCode == null || !_translations.containsKey(savedCode)) {
      return;
    }

    _localeCode = savedCode;
    notifyListeners();
  }

  Future<void> setLocaleCode(String localeCode) async {
    if (!_translations.containsKey(localeCode) || localeCode == _localeCode) {
      return;
    }

    _localeCode = localeCode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, localeCode);
  }

  String nativeLanguageName(String localeCode) {
    switch (localeCode) {
      case 'sw':
        return 'Kiswahili';
      case 'en':
      default:
        return 'English';
    }
  }

  String tr(String key, [Map<String, String> params = const {}]) {
    final template =
        _translations[_localeCode]?[key] ?? _translations['en']?[key] ?? key;

    var result = template;
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}
