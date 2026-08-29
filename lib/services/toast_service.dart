import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/tipi_toast_capsule.dart';

class ToastService {
  static final ToastService instance = ToastService._init();
  ToastService._init();

  OverlayEntry? _activeEntry;
  Timer? _autoDismissTimer;

  void showToast(
    BuildContext context, {
    required String title,
    required String message,
    bool isError = false,
  }) {
    // Dismiss any existing toast first
    dismiss();

    final overlayState = Overlay.of(context);
    final tintColor = isError ? const Color(0xFFEF4444) : const Color(0xFF0D5C2C);
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    _activeEntry = OverlayEntry(
      builder: (overlayContext) {
        return TipiToastCapsule(
          title: title,
          message: message,
          icon: icon,
          tintColor: tintColor,
          onDismiss: () {
            dismiss();
          },
        );
      },
    );

    overlayState.insert(_activeEntry!);

    // Auto dismiss after 3 seconds
    _autoDismissTimer = Timer(const Duration(seconds: 3), () {
      dismiss();
    });
  }

  void dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    
    if (_activeEntry != null) {
      _activeEntry!.remove();
      _activeEntry = null;
    }
  }
}
