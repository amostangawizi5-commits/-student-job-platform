import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

const Duration _appFeedbackDuration = Duration(minutes: 1);
const Color _successBackground = Color(0xFFE4F8E8);
const Color _successForeground = Color(0xFF1F6B33);
const Color _errorBackground = Color(0xFFFFE5E5);
const Color _errorForeground = Color(0xFF9F2D2D);

enum AppFeedbackTone { success, error }

class AppFeedbackOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void show(
    BuildContext context, {
    required String message,
    required AppFeedbackTone tone,
    Duration duration = _appFeedbackDuration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (message.trim().isEmpty) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismissCurrent();

    final entry = OverlayEntry(
      builder: (overlayContext) {
        final mediaQuery = MediaQuery.of(overlayContext);
        return Positioned(
          top: mediaQuery.padding.top + 8,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: _AppFeedbackBanner(
              message: message,
              tone: tone,
              duration: duration,
              actionLabel: actionLabel,
              onAction: onAction,
              onDismiss: dismissCurrent,
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    _currentEntry = entry;
    _dismissTimer = Timer(duration, dismissCurrent);
  }
}

extension AppSnackBarMessenger on ScaffoldMessengerState {
  void showAppSnackBar(SnackBar snackBar) {
    final message = _extractSnackBarMessage(snackBar.content).trim();
    if (message.isEmpty) return;

    AppFeedbackOverlay.dismissCurrent();
    hideCurrentSnackBar();
    showSnackBar(snackBar);
  }
}

String _extractSnackBarMessage(Widget content) {
  if (content is Text) {
    return content.data ?? content.textSpan?.toPlainText() ?? '';
  }

  if (content is RichText) {
    return content.text.toPlainText();
  }

  return '';
}

class _AppFeedbackBanner extends StatelessWidget {
  final String message;
  final AppFeedbackTone tone;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _AppFeedbackBanner({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isError = tone == AppFeedbackTone.error;
    final backgroundColor = isError ? _errorBackground : _successBackground;
    final foregroundColor = isError ? _errorForeground : _successForeground;
    final progressColor = isError ? AppTheme.error : AppTheme.primaryGreen;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: 0),
                duration: duration,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: foregroundColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(icon, color: foregroundColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (actionLabel != null && onAction != null)
                      TextButton(
                        onPressed: () {
                          onDismiss();
                          onAction!();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: foregroundColor,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(actionLabel!),
                      ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: onDismiss,
                      icon: Icon(Icons.close_rounded, color: foregroundColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
