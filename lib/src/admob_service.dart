import 'dart:async';

import 'package:easy_admob_ads_flutter/src/ad_helper.dart';
import 'package:easy_admob_ads_flutter/src/app_lifecycle_reactor.dart';
import 'package:easy_admob_ads_flutter/src/widgets/admob_app_open_ad.dart';
import 'package:easy_admob_ads_flutter/src/widgets/admob_consent_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

class AdmobService {
  static final Logger _logger = Logger('AdmobService');
  static final AdmobService _instance = AdmobService._internal();

  factory AdmobService() => _instance;

  AdmobService._internal();

  bool _isInitialized = false;
  late AppLifecycleReactor _appLifecycleReactor;
  final ConsentManager _consentManager = ConsentManager();

  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.warning('AdmobService is already initialized. Skipping.');
      return;
    }

    _logger.info('Starting AdmobService initialization...');
    _logger.fine('AdHelper.showConsentGDPR = ${AdHelper.showConsentGDPR}');

    // Step 1: Gather consent before initializing ads.
    _logger.info('Gathering user consent...');
    await _consentManager.gatherConsent();

    AdHelper.isPrivacyOptionsRequired = await _consentManager.isPrivacyOptionsRequired();
    _logger.fine('AdHelper.isPrivacyOptionsRequired = ${AdHelper.isPrivacyOptionsRequired}');

    // Step 2: Only initialize MobileAds if we are allowed to request ads.
    final canRequestAds = await _consentManager.canRequestAds();
    if (canRequestAds) {
      _logger.info('User has consented to ads. Initializing MobileAds...');
      await MobileAds.instance.initialize();

      if (kDebugMode) {
        final testDeviceIds = AdHelper.testDeviceIds;
        MobileAds.instance.updateRequestConfiguration(RequestConfiguration(testDeviceIds: testDeviceIds));
        _logger.fine('Test device IDs set: $testDeviceIds');
      }

      // Step 3: App open ad setup
      final appOpenAdManager = AdmobAppOpenAd();
      _logger.info('Loading App Open Ad...');
      _appLifecycleReactor = AppLifecycleReactor(appOpenAdManager: appOpenAdManager);
      await appOpenAdManager.loadAd();
      _appLifecycleReactor.listenToAppStateChanges();

      _isInitialized = true;
      _logger.info('AdmobService successfully initialized.');
    } else {
      _logger.warning('Ads cannot be requested due to lack of consent.');
    }
  }
}
