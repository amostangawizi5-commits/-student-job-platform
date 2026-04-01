import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'services/app_lock_service.dart';
import 'services/navigation_service.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';
import 'widgets/reset_pin_dialog.dart';

void main() {
  runApp(const MyApp());
}

bool shouldRequireImmediatePinOnBackground({required bool isCompany}) {
  return !isCompany;
}

bool shouldRequireCompanyPinAfterInactivity({
  required bool isCompany,
  required Duration inactiveFor,
  required Duration inactivityTimeout,
}) {
  return isCompany && inactiveFor >= inactivityTimeout;
}

bool canTrackSessionActivity({
  required bool isAuthenticated,
  required bool isPinVisible,
  required bool shouldRequirePinOnResume,
}) {
  return isAuthenticated && !isPinVisible && !shouldRequirePinOnResume;
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
            navigatorKey: appNavigatorKey,
            title: 'IGS TZ',
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
              appBarTheme: AppBarTheme(
                elevation: 0,
                backgroundColor: AppTheme.white,
                foregroundColor: AppTheme.textDark,
                centerTitle: false,
                titleSpacing: 0,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppTheme.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue),
                ),
              ),
            ),
            builder: (context, child) =>
                _SessionGuard(child: child ?? const SizedBox.shrink()),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class _SessionGuard extends StatefulWidget {
  final Widget child;

  const _SessionGuard({required this.child});

  @override
  State<_SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<_SessionGuard>
    with WidgetsBindingObserver {
  static const Duration _inactivityTimeout = Duration(minutes: 3);

  final GlobalKey<NavigatorState> _pinGateNavigatorKey =
      GlobalKey<NavigatorState>();
  bool _isPinVisible = false;
  bool _isSetupMode = false;
  bool _isEvaluatingPin = false;
  bool _shouldRequirePinOnResume = false;
  String _authStateKey = '';
  Timer? _inactivityTimer;
  DateTime? _lastActivityAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _cancelInactivityTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluatePinRequirement();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuthenticated &&
          shouldRequireImmediatePinOnBackground(
            isCompany: authProvider.isCompany,
          )) {
        _shouldRequirePinOnResume = true;
      }
      _cancelInactivityTimer();
    }
  }

  Future<void> _evaluatePinRequirement() async {
    if (_isEvaluatingPin || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      if (_isPinVisible && mounted) {
        setState(() => _isPinVisible = false);
      }
      _isSetupMode = false;
      _shouldRequirePinOnResume = false;
      _cancelInactivityTimer();
      _lastActivityAt = null;
      return;
    }

    _isEvaluatingPin = true;
    try {
      final hasPin = await AppLockService.forUser(authProvider.user).hasPin();
      if (!mounted) {
        return;
      }

      final shouldShowSetup = !hasPin && authProvider.requiresPinSetup;
      final inactiveFor = _lastActivityAt == null
          ? Duration.zero
          : DateTime.now().difference(_lastActivityAt!);
      final shouldShowCompanyUnlock = shouldRequireCompanyPinAfterInactivity(
        isCompany: authProvider.isCompany,
        inactiveFor: inactiveFor,
        inactivityTimeout: _inactivityTimeout,
      );
      final shouldShowUnlock =
          hasPin &&
          (authProvider.sessionRestored ||
              _shouldRequirePinOnResume ||
              shouldShowCompanyUnlock);

      if (shouldShowSetup || shouldShowUnlock) {
        setState(() {
          _isSetupMode = shouldShowSetup;
          _isPinVisible = true;
        });
        _cancelInactivityTimer();
      } else if (!_isPinVisible && hasPin) {
        _restartInactivityTimerIfNeeded();
      }
    } catch (_) {
      // Leave the current gate state unchanged if secure storage is unavailable.
      if (!mounted) {
        return;
      }
    } finally {
      _isEvaluatingPin = false;
    }
  }

  void _handleAuthState(AuthProvider authProvider) {
    final nextKey =
        '${authProvider.isAuthenticated}-${authProvider.sessionRestored}-${authProvider.requiresPinSetup}';
    if (_authStateKey == nextKey) return;

    _authStateKey = nextKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _evaluatePinRequirement();
    });
  }

  Future<void> _handlePinUnlocked() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    authProvider.markSessionUnlocked();
    setState(() => _isPinVisible = false);
    _isSetupMode = false;
    _shouldRequirePinOnResume = false;
    _markUserActivity();
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _restartInactivityTimerIfNeeded() {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated || _isPinVisible) {
      _cancelInactivityTimer();
      return;
    }

    final lastActivityAt = _lastActivityAt ?? DateTime.now();
    final inactiveFor = DateTime.now().difference(lastActivityAt);
    if (inactiveFor >= _inactivityTimeout) {
      _triggerInactivityLock();
      return;
    }

    _cancelInactivityTimer();
    _inactivityTimer = Timer(_inactivityTimeout - inactiveFor, () {
      if (!mounted) return;
      _triggerInactivityLock();
    });
  }

  void _markUserActivity() {
    final authProvider = context.read<AuthProvider>();
    if (!canTrackSessionActivity(
      isAuthenticated: authProvider.isAuthenticated,
      isPinVisible: _isPinVisible,
      shouldRequirePinOnResume: _shouldRequirePinOnResume,
    )) {
      return;
    }

    _lastActivityAt = DateTime.now();
    _restartInactivityTimerIfNeeded();
  }

  Future<void> _triggerInactivityLock() async {
    if (!mounted || _isPinVisible || _isSetupMode) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) {
      _cancelInactivityTimer();
      return;
    }

    _shouldRequirePinOnResume = true;
    await _evaluatePinRequirement();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    _handleAuthState(authProvider);

    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _markUserActivity(),
          onPointerMove: (_) => _markUserActivity(),
          onPointerPanZoomStart: (_) => _markUserActivity(),
          onPointerSignal: (_) => _markUserActivity(),
          child: widget.child,
        ),
        if (_isPinVisible && authProvider.isAuthenticated)
          Positioned.fill(
            child: HeroControllerScope.none(
              child: Navigator(
                key: _pinGateNavigatorKey,
                onGenerateRoute: (_) => PageRouteBuilder<void>(
                  opaque: false,
                  barrierColor: Colors.transparent,
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (_, _, _) => AppPinGate(
                    isSetup: _isSetupMode,
                    onUnlocked: _handlePinUnlocked,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AppPinGate extends StatefulWidget {
  final bool isSetup;
  final Future<void> Function() onUnlocked;
  final AppLockService? appLockService;

  const AppPinGate({
    super.key,
    required this.isSetup,
    required this.onUnlocked,
    this.appLockService,
  });

  @override
  State<AppPinGate> createState() => _AppPinGateState();
}

class _AppPinGateState extends State<AppPinGate> {
  static const String _pinVerificationError =
      'Unable to verify PIN right now. Please try again.';
  static const String _pinSaveError =
      'Unable to save PIN right now. Please try again.';

  late final AppLockService _appLockService;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final FocusNode _confirmPinFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isPinObscured = true;
  bool _isConfirmPinObscured = true;
  bool _pinEntryPrimed = false;
  bool _confirmPinEntryPrimed = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _appLockService =
        widget.appLockService ??
        AppLockService.forUser(context.read<AuthProvider>().user);
    _resetPinFields();
    _pinFocusNode.addListener(_handlePinFocusChange);
    _confirmPinFocusNode.addListener(_handleConfirmPinFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppPinGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSetup != widget.isSetup) {
      _resetPinFields();
    }
  }

  void _resetPinFields() {
    _pinController.clear();
    _confirmPinController.clear();
    _pinEntryPrimed = false;
    _confirmPinEntryPrimed = false;
    _errorText = null;
  }

  void _clearPinInput(TextEditingController controller) {
    controller
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    if (!mounted) return;
    setState(() {
      _errorText = null;
    });
  }

  void _prepareManualPinEntry({
    required FocusNode focusNode,
    required TextEditingController controller,
    required bool alreadyPrimed,
    required void Function() markPrimed,
  }) {
    if (!focusNode.hasFocus || alreadyPrimed) return;
    TextInput.finishAutofillContext(shouldSave: false);
    controller
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    markPrimed();
  }

  void _handlePinFocusChange() {
    _prepareManualPinEntry(
      focusNode: _pinFocusNode,
      controller: _pinController,
      alreadyPrimed: _pinEntryPrimed,
      markPrimed: () => _pinEntryPrimed = true,
    );
  }

  void _handleConfirmPinFocusChange() {
    _prepareManualPinEntry(
      focusNode: _confirmPinFocusNode,
      controller: _confirmPinController,
      alreadyPrimed: _confirmPinEntryPrimed,
      markPrimed: () => _confirmPinEntryPrimed = true,
    );
  }

  @override
  void dispose() {
    _pinFocusNode
      ..removeListener(_handlePinFocusChange)
      ..dispose();
    _confirmPinFocusNode
      ..removeListener(_handleConfirmPinFocusChange)
      ..dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _errorText = 'Enter a valid 4-digit PIN');
      return;
    }

    if (widget.isSetup) {
      if (confirmPin != pin) {
        setState(() => _errorText = 'PINs do not match');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      if (widget.isSetup) {
        await _appLockService.savePin(pin);
        if (!mounted) return;
        await widget.onUnlocked();
        return;
      }

      final isValid = await _appLockService.verifyPin(pin);
      if (!mounted) return;

      if (!isValid) {
        setState(() {
          _isSubmitting = false;
          _errorText = 'Incorrect PIN';
        });
        return;
      }

      await widget.onUnlocked();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = widget.isSetup ? _pinSaveError : _pinVerificationError;
      });
    }
  }

  Future<void> _resetPinWithPassword() async {
    final email = context.read<AuthProvider>().user?['email']?.toString() ?? '';
    if (email.isEmpty) {
      setState(() => _errorText = 'Unable to verify account for PIN reset');
      return;
    }

    final changed = await showResetPinDialog(
      context,
      email: email,
      title: 'Reset PIN',
    );
    if (!mounted || changed != true) return;

    await widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF0F172A).withValues(alpha: 0.82),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFF1D4ED8),
                      size: 36,
                    ),
                  ),
                  Text(
                    widget.isSetup ? 'Create App PIN' : 'Enter App PIN',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isSetup
                        ? 'Set a 4-digit PIN. You will enter it every time the app is opened again.'
                        : 'Enter your 4-digit PIN to unlock the app.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: widget.isSetup
                        ? TextInputAction.next
                        : TextInputAction.done,
                    obscureText: _isPinObscured,
                    maxLength: 4,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    enableInteractiveSelection: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    autofillHints: null,
                    onTap: () {
                      TextInput.finishAutofillContext(shouldSave: false);
                    },
                    onChanged: (_) {
                      if (!mounted) return;
                      setState(() {
                        _errorText = null;
                      });
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      counterText: '',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_pinController.text.isNotEmpty)
                            IconButton(
                              onPressed: () => _clearPinInput(_pinController),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          IconButton(
                            onPressed: () {
                              setState(() => _isPinObscured = !_isPinObscured);
                            },
                            icon: Icon(
                              _isPinObscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.isSetup) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPinController,
                      focusNode: _confirmPinFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      obscureText: _isConfirmPinObscured,
                      maxLength: 4,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      enableInteractiveSelection: false,
                      smartDashesType: SmartDashesType.disabled,
                      smartQuotesType: SmartQuotesType.disabled,
                      autofillHints: null,
                      onTap: () {
                        TextInput.finishAutofillContext(shouldSave: false);
                      },
                      onChanged: (_) {
                        if (!mounted) return;
                        setState(() {
                          _errorText = null;
                        });
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Confirm PIN',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        counterText: '',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_confirmPinController.text.isNotEmpty)
                              IconButton(
                                onPressed: () =>
                                    _clearPinInput(_confirmPinController),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            IconButton(
                              onPressed: () {
                                setState(
                                  () => _isConfirmPinObscured =
                                      !_isConfirmPinObscured,
                                );
                              },
                              icon: Icon(
                                _isConfirmPinObscured
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(widget.isSetup ? 'Save PIN' : 'Unlock'),
                    ),
                  ),
                  if (!widget.isSetup) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isSubmitting ? null : _resetPinWithPassword,
                      child: const Text('Forgot PIN? Reset with password'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
