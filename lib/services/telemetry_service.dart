import 'package:flutter/foundation.dart';

class TelemetryService {
  static final TelemetryService instance = TelemetryService._init();
  
  TelemetryService._init();

  // Log error with optional stack trace
  void logError(dynamic error, [StackTrace? stackTrace, String? context]) {
    final errorMessage = "TELEMETRY ERROR: [Context: $context] $error";
    
    if (kDebugMode) {
      debugPrint(errorMessage);
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    } else {
      // In production mode, forward exceptions to Sentry / Firebase Crashlytics:
      // Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  // Log info messages
  void logInfo(String message) {
    if (kDebugMode) {
      debugPrint("TELEMETRY INFO: $message");
    } else {
      // Sentry.addBreadcrumb(Breadcrumb(message: message));
    }
  }
}
