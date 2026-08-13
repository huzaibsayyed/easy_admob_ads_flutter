import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

/// Exception class for handling ad-related errors.
class AdException implements Exception {
  static final Logger _logger = Logger('AdException');

  /// Entry point for ad error handling.
  static void check(LoadAdError error, {required String adUnitId, adType}) {
    if (!kDebugMode) return; // Skip in release mode

    if (_isCriticalConfigError(error)) {
      _terminateApp(error, adUnitId: adUnitId, adType: adType);
    } else {
      _logger.warning('⚠️ Non-critical ad load error: ${error.message}');
    }
  }

  /// Stops app execution and logs critical ad format mismatch.
  static void _terminateApp(LoadAdError error, {String? adUnitId, String? adType}) {
    final adUnit = adUnitId ?? 'unknown';

    final details = FlutterErrorDetails(
      exception: FlutterError('❌ AdMob Format Mismatch for adUnit: $adUnit'),
      library: 'easy_admob_ads_flutter',
      summary: [
        '❌ AdMob Format Mismatch',
        '🔹 Ad Type: $adType',
        '🔹 Ad Unit: $adUnit',
        '🔹 Ad Error Code: ${error.code}',
        '🔹 Ad Error Message: ${error.message}',
        '🔧 Fixes:',
        '   1. Verify Ad Unit ID',
        '   2. Match format in AdMob',
        '   3. Use correct ad type',
        '⚠️ Retrying won’t help — fix the config.',
      ].join('\n'),
    );

    // Report the error so it shows up in the Flutter error handling UI/console
    FlutterError.reportError(details);

    // In debug, throw to fail fast and help developers notice the misconfiguration.
    if (kDebugMode) {
      throw FlutterError('Admob Ad configuration error detected. See Flutter error details in the console.');
    }

    // In release, we log the details and continue running (don't crash user's app in production).
    _logger.severe(details.summary);
  }

  static bool _isCriticalConfigError(LoadAdError error) {
    final message = error.message.toLowerCase();

    return error.code == 0 || // Invalid Request
        message.contains("cannot determine request type") ||
        message.contains("is your ad unit id correct") ||
        message.contains("ad unit doesn't match format") ||
        message.contains("publisher data not found") ||
        message.contains("data not found") ||
        message.contains("invalid ad unit") ||
        message.contains("not configured");
  }
}
