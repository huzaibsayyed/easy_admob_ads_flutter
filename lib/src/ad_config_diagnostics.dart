import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

/// Surfaces likely AdMob configuration mistakes (wrong ad unit ID, ad unit
/// used with the wrong format, etc.) loudly during development so they get
/// fixed before release instead of silently costing you impressions.
class AdConfigDiagnostics {
  static final Logger _logger = Logger('AdConfigDiagnostics');

  static void check(LoadAdError error, {required String adUnitId, required String adType}) {
    if (!kDebugMode) return; // Only surfaced during development

    if (!_looksLikeConfigMismatch(error)) {
      _logger.warning('⚠️ $adType ad failed to load: ${error.message}');
      return;
    }

    final message = [
      '❌ Possible AdMob configuration mismatch',
      '🔹 Ad Type: $adType',
      '🔹 Ad Unit: $adUnitId',
      '🔹 Error Code: ${error.code}',
      '🔹 Error Message: ${error.message}',
      '🔧 Check that the ad unit ID exists, is enabled, and matches this ad format in the AdMob console.',
    ].join('\n');

    _logger.severe(message);
    FlutterError.reportError(FlutterErrorDetails(exception: StateError(message), library: 'easy_admob_ads_flutter'));
  }

  static bool _looksLikeConfigMismatch(LoadAdError error) {
    final message = error.message.toLowerCase();
    return error.code == 0 ||
        message.contains('cannot determine request type') ||
        message.contains('is your ad unit id correct') ||
        message.contains("ad unit doesn't match format") ||
        message.contains('publisher data not found') ||
        message.contains('data not found') ||
        message.contains('invalid ad unit') ||
        message.contains('not configured');
  }
}
