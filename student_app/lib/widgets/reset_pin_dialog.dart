import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import '../services/navigation_service.dart';

Future<bool?> showResetPinDialog(
  BuildContext context, {
  required String email,
  String title = 'Reset PIN',
}) {
  final dialogContext = appNavigatorKey.currentContext ?? context;
  return showDialog<bool>(
    context: dialogContext,
    useRootNavigator: true,
    builder: (_) => ResetPinDialog(email: email, title: title),
  );
}

class ResetPinDialog extends StatefulWidget {
  final String email;
  final String title;

  const ResetPinDialog({
    super.key,
    required this.email,
    this.title = 'Reset PIN',
  });

  @override
  State<ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends State<ResetPinDialog> {
  final ApiService _apiService = ApiService();
  final AppLockService _appLockService = AppLockService();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _newPinFocusNode = FocusNode();
  final FocusNode _confirmPinFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showNewPin = false;
  bool _showConfirmPin = false;
  bool _newPinEntryPrimed = false;
  bool _confirmPinEntryPrimed = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _newPinFocusNode.addListener(_handleNewPinFocusChange);
    _confirmPinFocusNode.addListener(_handleConfirmPinFocusChange);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _newPinFocusNode
      ..removeListener(_handleNewPinFocusChange)
      ..dispose();
    _confirmPinFocusNode
      ..removeListener(_handleConfirmPinFocusChange)
      ..dispose();
    super.dispose();
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

  void _handleNewPinFocusChange() {
    _prepareManualPinEntry(
      focusNode: _newPinFocusNode,
      controller: _newPinController,
      alreadyPrimed: _newPinEntryPrimed,
      markPrimed: () => _newPinEntryPrimed = true,
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

  void _clearPinInput(TextEditingController controller) {
    controller
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    if (!mounted) return;
    setState(() {
      _errorText = null;
    });
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorText = 'Enter your account password');
      return;
    }
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      setState(() => _errorText = 'Enter a valid new 4-digit PIN');
      return;
    }
    if (confirmPin != newPin) {
      setState(() => _errorText = 'PINs do not match');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final response = await _apiService.verifyAccountPassword(
      email: widget.email,
      password: password,
    );
    if (!mounted) return;

    if (response['success'] != true) {
      setState(() {
        _isSubmitting = false;
        _errorText =
            response['message']?.toString() ?? 'Password verification failed';
      });
      return;
    }

    await _appLockService.savePin(newPin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify your account password, then create a new 4-digit PIN.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: false,
              decoration: _inputDecoration(
                labelText: 'Account password',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPinController,
              focusNode: _newPinFocusNode,
              keyboardType: TextInputType.number,
              obscureText: !_showNewPin,
              maxLength: 4,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              enableInteractiveSelection: true,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              autofillHints: null,
              onTap: () {
                TextInput.finishAutofillContext(shouldSave: false);
              },
              onChanged: (_) {
                if (!mounted) return;
                setState(() => _errorText = null);
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: _inputDecoration(
                labelText: 'New PIN',
                icon: Icons.pin_outlined,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_newPinController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear PIN',
                        onPressed: () => _clearPinInput(_newPinController),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      onPressed: () {
                        setState(() => _showNewPin = !_showNewPin);
                      },
                      icon: Icon(
                        _showNewPin
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPinController,
              focusNode: _confirmPinFocusNode,
              keyboardType: TextInputType.number,
              obscureText: !_showConfirmPin,
              maxLength: 4,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              enableInteractiveSelection: true,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              autofillHints: null,
              onTap: () {
                TextInput.finishAutofillContext(shouldSave: false);
              },
              onChanged: (_) {
                if (!mounted) return;
                setState(() => _errorText = null);
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: _inputDecoration(
                labelText: 'Confirm PIN',
                icon: Icons.verified_user_outlined,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_confirmPinController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear PIN',
                        onPressed: () => _clearPinInput(_confirmPinController),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      onPressed: () {
                        setState(() => _showConfirmPin = !_showConfirmPin);
                      },
                      icon: Icon(
                        _showConfirmPin
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reset PIN'),
        ),
      ],
    );
  }
}
