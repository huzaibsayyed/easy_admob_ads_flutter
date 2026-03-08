import 'dart:async';

import 'package:easy_admob_ads_flutter/easy_admob_ads_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

typedef OnConsentGatheringCompleteListener = void Function(FormError? error);

/// The Google Mobile Ads SDK provides the User Messaging Platform (Google's IAB
/// Certified consent management platform) as one solution to capture consent for
/// users in GDPR impacted countries. This is an example and you can choose
/// another consent management platform to capture consent.
class ConsentManager {
  static final Logger _logger = Logger('AdmobConsentManager');

  /// Helper variable to determine if the app can request ads.
  Future<bool> canRequestAds() async {
    return await ConsentInformation.instance.canRequestAds();
  }

  /// Helper variable to determine if the privacy options form is required.
  Future<bool> isPrivacyOptionsRequired() async {
    return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
  }

  /// Helper method to call the Mobile Ads SDK to request consent information
  /// and load/show a consent form if necessary.
  void gatherConsent(OnConsentGatheringCompleteListener onConsentGatheringCompleteListener) {
    // For testing purposes, you can force a DebugGeography of Eea or NotEea.
    ConsentDebugSettings? debugSettings;

    if (AdHelper.showConstentGDPR && kDebugMode) {
      debugSettings = ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
        testIdentifiers: AdHelper.testDeviceIds,
      );
    }
    ConsentRequestParameters params = ConsentRequestParameters(consentDebugSettings: debugSettings);

    // Requesting an update to consent information should be called on every app launch.
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((loadAndShowError) {
          // Consent has been gathered.
          onConsentGatheringCompleteListener(loadAndShowError);
        });
      },
      (FormError formError) {
        onConsentGatheringCompleteListener(formError);
      },
    );
  }

  /// Helper method to call the Mobile Ads SDK method to show the privacy options form.
  void showPrivacyOptionsForm(OnConsentFormDismissedListener onConsentFormDismissedListener) {
    _logger.info('Showing Consent - AdHelper.showConstentGDPR = ${AdHelper.showConstentGDPR}');
    ConsentForm.showPrivacyOptionsForm(onConsentFormDismissedListener);
  }
}
