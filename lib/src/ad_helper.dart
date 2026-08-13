import 'dart:io';
import 'package:easy_admob_ads_flutter/easy_admob_ads_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'ad_id_registry.dart';
import 'ad_type.dart';

class AdHelper {
  static final Logger _logger = Logger('AdHelper');

  // Global flag to enable/disable ads throughout the app
  static bool showAds = true;

  // Flag specifically for App Open Ads
  static bool showAppOpenAds = true;

  // Flag specifically for Consent GDPR (renamed from showConstentGDPR)
  static bool showConsentGDPR = false;

  // Flag for Consent
  static bool isPrivacyOptionsRequired = false;

  // Test ids
  static List<String> testDeviceIds = <String>[];

  /// Call this from your app's main() if you want to see logs from this package.
  static void setupAdLogging({Level level = Level.ALL}) {
    if (kDebugMode) {
      Logger.root.level = level;
      Logger.root.onRecord.listen((record) {
        debugPrint('[${record.level.name}] ${record.loggerName}: ${record.message}');
      });
    }
  }

  // Get Banner Ad Unit ID (lazy lookup)
  static String get bannerAdUnitId {
    final adTypeMap = AdIdRegistry.currentPlatformAdIds;
    if (Platform.isAndroid) {
      return adTypeMap[AdType.banner] ?? '';
    } else if (Platform.isIOS) {
      return adTypeMap[AdType.banner] ?? '';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get Interstitial Ad Unit ID
  static String get interstitialAdUnitId {
    final adTypeMap = AdIdRegistry.currentPlatformAdIds;
    if (Platform.isAndroid) {
      return adTypeMap[AdType.interstitial] ?? '';
    } else if (Platform.isIOS) {
      return adTypeMap[AdType.interstitial] ?? '';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get Rewarded Ad Unit ID
  static String get rewardedAdUnitId {
    final adTypeMap = AdIdRegistry.currentPlatformAdIds;
    if (Platform.isAndroid) {
      return adTypeMap[AdType.rewarded] ?? '';
    } else if (Platform.isIOS) {
      return adTypeMap[AdType.rewarded] ?? '';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get Rewarded Interstitial Ad Unit ID
  static String get rewardedInterstitialAdUnitId {
    final adTypeMap = AdIdRegistry.currentPlatformAdIds;
    if (Platform.isAndroid) {
      return adTypeMap[AdType.rewardedInterstitial] ?? '';
    } else if (Platform.isIOS) {
      return adTypeMap[AdType.rewardedInterstitial] ?? '';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get App Open Ad Unit ID
  static String get appOpenAdUnitId {
    final adTypeMap = AdIdRegistry.currentPlatformAdIds;
    if (Platform.isAndroid) {
      return adTypeMap[AdType.appOpen] ?? '';
    } else if (Platform.isIOS) {
      return adTypeMap[AdType.appOpen] ?? '';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Get Native Ad Unit ID
  static String get nativeAdUnitId {
    final adTypeMap = AdIdRegistry.currentPlatformAdIds;
    if (Platform.isAndroid) {
      return adTypeMap[AdType.native] ?? '';
    } else if (Platform.isIOS) {
      return adTypeMap[AdType.native] ?? '';
    }
    throw UnsupportedError('Unsupported platform');
  }
}
