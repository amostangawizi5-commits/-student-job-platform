import 'package:flutter/material.dart';

class LanguagePickerDialog extends StatefulWidget {
  final String titleText;
  final String cancelText;
  final String applyText;
  final String currentLanguageCode;
  final List<LanguageOption> options;

  const LanguagePickerDialog({
    super.key,
    required this.titleText,
    required this.cancelText,
    required this.applyText,
    required this.currentLanguageCode,
    required this.options,
  });

  @override
  State<LanguagePickerDialog> createState() => _LanguagePickerDialogState();
}

class _LanguagePickerDialogState extends State<LanguagePickerDialog> {
  late String _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = widget.currentLanguageCode;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titleText),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.options.map((option) {
          final isSelected = _selectedLanguageCode == option.code;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            ),
            title: Text(option.label),
            onTap: () {
              setState(() => _selectedLanguageCode = option.code);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedLanguageCode),
          child: Text(widget.applyText),
        ),
      ],
    );
  }
}

class LanguageOption {
  final String code;
  final String label;

  const LanguageOption({required this.code, required this.label});
}
