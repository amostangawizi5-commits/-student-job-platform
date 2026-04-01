import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/main.dart';
import 'package:student_app/services/app_lock_service.dart';

class _FakeAppLockService extends AppLockService {
  _FakeAppLockService({this.throwOnVerify = false});

  final bool throwOnVerify;

  @override
  Future<bool> verifyPin(String pin) async {
    if (throwOnVerify) {
      throw Exception('secure storage unavailable');
    }
    return false;
  }
}

void main() {
  test('PIN storage key is scoped per account', () {
    expect(
      buildAppLockPinStorageKey(
        buildAppLockAccountScope({
          'role': 'company',
          'user_id': '42',
          'email': 'company@example.com',
        }),
      ),
      'app_lock_pin_v2_company:42',
    );
    expect(
      buildAppLockPinStorageKey(
        buildAppLockAccountScope({
          'role': 'admin',
          'user_id': '7',
          'email': 'admin@example.com',
        }),
      ),
      'app_lock_pin_v2_admin:7',
    );
  });

  test('activity tracking stays blocked while resume unlock is pending', () {
    expect(
      canTrackSessionActivity(
        isAuthenticated: true,
        isPinVisible: false,
        shouldRequirePinOnResume: true,
      ),
      isFalse,
    );
  });

  test('activity tracking resumes after unlock gate is cleared', () {
    expect(
      canTrackSessionActivity(
        isAuthenticated: true,
        isPinVisible: false,
        shouldRequirePinOnResume: false,
      ),
      isTrue,
    );
  });

  test('company only requires PIN after 3 minutes of inactivity', () {
    expect(shouldRequireImmediatePinOnBackground(isCompany: true), isFalse);
    expect(
      shouldRequireCompanyPinAfterInactivity(
        isCompany: true,
        inactiveFor: const Duration(minutes: 2, seconds: 59),
        inactivityTimeout: const Duration(minutes: 3),
      ),
      isFalse,
    );
    expect(
      shouldRequireCompanyPinAfterInactivity(
        isCompany: true,
        inactiveFor: const Duration(minutes: 3),
        inactivityTimeout: const Duration(minutes: 3),
      ),
      isTrue,
    );
  });

  test('non-company accounts still lock immediately on background', () {
    expect(shouldRequireImmediatePinOnBackground(isCompany: false), isTrue);
    expect(
      shouldRequireCompanyPinAfterInactivity(
        isCompany: false,
        inactiveFor: const Duration(minutes: 10),
        inactivityTimeout: const Duration(minutes: 3),
      ),
      isFalse,
    );
  });

  Widget buildGate(AppLockService appLockService) {
    return MaterialApp(
      home: Scaffold(
        body: AppPinGate(
          isSetup: false,
          appLockService: appLockService,
          onUnlocked: () async {},
        ),
      ),
    );
  }

  testWidgets('keeps unlock gate visible when PIN is incorrect', (
    tester,
  ) async {
    await tester.pumpWidget(buildGate(_FakeAppLockService()));

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.byType(AppPinGate), findsOneWidget);
    expect(find.text('Incorrect PIN'), findsOneWidget);
  });

  testWidgets('shows a friendly error when PIN verification throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildGate(_FakeAppLockService(throwOnVerify: true)),
    );

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.byType(AppPinGate), findsOneWidget);
    expect(
      find.text('Unable to verify PIN right now. Please try again.'),
      findsOneWidget,
    );
  });
}
