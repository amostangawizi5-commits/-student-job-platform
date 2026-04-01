import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/app_lock_service.dart';

Future<bool?> showChangePinDialog(
  BuildContext context, {
  String title = 'Change PIN',
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (_) => ChangePinDialog(title: title),
  );
}

class ChangePinDialog extends StatefulWidget {
  final String title;

  const ChangePinDialog({super.key, this.title = 'Change PIN'});

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  static const String _pinStateLoadError =
      'Unable to load PIN settings right now. Please try again.';
  static const String _pinUpdateError =
      'Unable to update PIN right now. Please try again.';

  late final AppLockService _appLockService;
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _currentPinFocusNode = FocusNode();
  final FocusNode _newPinFocusNode = FocusNode();
  final FocusNode _confirmPinFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasExistingPin = false;
  bool _showCurrentPin = false;
  bool _showNewPin = false;
  bool _showConfirmPin = false;
  bool _currentPinEntryPrimed = false;
  bool _newPinEntryPrimed = false;
  bool _confirmPinEntryPrimed = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _appLockService = AppLockService.forUser(context.read<AuthProvider>().user);
    _currentPinFocusNode.addListener(_handleCurrentPinFocusChange);
    _newPinFocusNode.addListener(_handleNewPinFocusChange);
    _confirmPinFocusNode.addListener(_handleConfirmPinFocusChange);
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    try {
      final hasPin = await _appLockService.hasPin();
      if (!mounted) return;
      setState(() {
        _hasExistingPin = hasPin;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = _pinStateLoadError;
      });
    }
  }

  @override
  void dispose() {
    _currentPinFocusNode
      ..removeListener(_handleCurrentPinFocusChange)
      ..dispose();
    _newPinFocusNode
      ..removeListener(_handleNewPinFocusChange)
      ..dispose();
    _confirmPinFocusNode
      ..removeListener(_handleConfirmPinFocusChange)
      ..dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
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

  void _handleCurrentPinFocusChange() {
    _prepareManualPinEntry(
      focusNode: _currentPinFocusNode,
      controller: _currentPinController,
      alreadyPrimed: _currentPinEntryPrimed,
      markPrimed: () => _currentPinEntryPrimed = true,
    );
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

  void _closeDialog([bool? result]) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
    }
  }

  Future<void> _submit() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (_hasExistingPin) {
      if (currentPin.length != 4 || int.tryParse(currentPin) == null) {
        setState(() => _errorText = 'Enter your current 4-digit PIN');
        return;
      }

      try {
        final isCurrentPinValid = await _appLockService.verifyPin(currentPin);
        if (!mounted) return;
        if (!isCurrentPinValid) {
          setState(() => _errorText = 'Current PIN is incorrect');
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _errorText = _pinUpdateError);
        return;
      }
    }

    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      setState(() => _errorText = 'Enter a valid new 4-digit PIN');
      return;
    }

    if (_hasExistingPin && currentPin == newPin) {
      setState(() => _errorText = 'New PIN must be different');
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

    try {
      await _appLockService.savePin(newPin);
      if (!mounted) return;
      _closeDialog(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = _pinUpdateError;
      });
    }
  }

  InputDecoration _pinDecoration({
    required String labelText,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggle,
    required TextEditingController controller,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon),
      counterText: '',
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear PIN',
              onPressed: () => _clearPinInput(controller),
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              isVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      obscureText: !isVisible,
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
        setState(() => _errorText = null);
      },
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: _pinDecoration(
        labelText: labelText,
        icon: icon,
        isVisible: isVisible,
        onToggle: onToggle,
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasExistingPin
                        ? 'Update your 4-digit PIN used to unlock the app.'
                        : 'Create a 4-digit PIN used to unlock the app.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (_hasExistingPin) ...[
                    _buildPinField(
                      controller: _currentPinController,
                      focusNode: _currentPinFocusNode,
                      labelText: 'Current PIN',
                      icon: Icons.lock_outline_rounded,
                      isVisible: _showCurrentPin,
                      onToggle: () {
                        setState(() => _showCurrentPin = !_showCurrentPin);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildPinField(
                    controller: _newPinController,
                    focusNode: _newPinFocusNode,
                    labelText: 'New PIN',
                    icon: Icons.pin_outlined,
                    isVisible: _showNewPin,
                    onToggle: () {
                      setState(() => _showNewPin = !_showNewPin);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPinField(
                    controller: _confirmPinController,
                    focusNode: _confirmPinFocusNode,
                    labelText: 'Confirm PIN',
                    icon: Icons.verified_user_outlined,
                    isVisible: _showConfirmPin,
                    onToggle: () {
                      setState(() => _showConfirmPin = !_showConfirmPin);
                    },
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
          onPressed: _isSubmitting ? null : _closeDialog,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_hasExistingPin ? 'Update PIN' : 'Save PIN'),
        ),
      ],
    );
  }
}
