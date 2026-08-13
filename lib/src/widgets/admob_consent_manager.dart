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
  /// and load/show a consent form if necessary. Returns when the process
  /// completes (either successfully or with an error).
  Future<void> gatherConsent() async {
    // For testing purposes, you can force a DebugGeography of Eea or NotEea.
    ConsentDebugSettings? debugSettings;

    if (AdHelper.showConsentGDPR && kDebugMode) {
      debugSettings = ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea);
    }
    ConsentRequestParameters params = ConsentRequestParameters(consentDebugSettings: debugSettings);

    final completer = Completer<void>();

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // On success: attempt to load and show the consent form if required.
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? loadAndShowError) {
            if (loadAndShowError != null) {
              _logger.warning('Consent form load/show returned error: ${loadAndShowError.message}');
            } else {
              _logger.info('Consent form shown or not required.');
            }
            // Complete regardless of whether form was shown/required
            if (!completer.isCompleted) completer.complete();
          });
        },
        (FormError formError) {
          _logger.warning('requestConsentInfoUpdate failed: ${formError.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );

      return completer.future;
    } catch (e) {
      _logger.warning('Error while gathering consent: $e');
      if (!completer.isCompleted) completer.complete();
      return completer.future;
    }
  }

  /// Helper method to call the Mobile Ads SDK method to show the privacy options form.
  Future<void> showPrivacyOptionsForm() async {
    _logger.info('Showing Consent - AdHelper.showConsentGDPR = ${AdHelper.showConsentGDPR}');
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) _logger.warning('Privacy options form error: ${error.message}');
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}
