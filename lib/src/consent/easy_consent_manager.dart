import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

/// Wraps Google's User Messaging Platform (UMP) SDK to gather GDPR consent.
///
/// You normally don't need to use this directly — [EasyAdMobAds.initialize]
/// calls it for you. It's exposed so you can call [showPrivacyOptionsForm]
/// from a settings screen.
class EasyConsentManager {
  static final Logger _logger = Logger('EasyConsentManager');

  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Requests up-to-date consent info and shows the consent form if required.
  /// Completes once consent has been gathered (or an error occurred).
  Future<void> requestConsent({bool simulateEeaConsentInDebug = false}) {
    final completer = Completer<void>();

    ConsentDebugSettings? debugSettings;
    if (simulateEeaConsentInDebug && kDebugMode) {
      debugSettings = ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea);
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(consentDebugSettings: debugSettings),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (error != null) {
              _logger.warning('Consent form error: ${error.errorCode} - ${error.message}');
            } else {
              _logger.info('Consent gathered.');
            }
            if (!completer.isCompleted) completer.complete();
          });
        },
        (FormError error) {
          _logger.severe('Failed to request consent info: ${error.errorCode} - ${error.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e, stackTrace) {
      // requestConsentInfoUpdate can throw (rather than report failure via its
      // callback) if the platform channel call itself fails — e.g. a brand-new
      // AdMob App ID that hasn't finished propagating yet. Treat that the same
      // as a reported failure instead of letting it escape uncaught out of
      // EasyAdMobAds.initialize(), which main() awaits before runApp().
      _logger.severe('requestConsentInfoUpdate threw unexpectedly', e, stackTrace);
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  /// Shows the "privacy options" form so users can change their consent choice.
  ///
  /// Only call this when [isPrivacyOptionsRequired] is true — the platform
  /// SDK throws instead of reporting a clean error when there's no privacy
  /// options form available for the current user (e.g. outside a region that
  /// requires one). That throw is caught here and reported through
  /// [onDismissed] like any other form error, so callers don't need their own
  /// try/catch, but still check [isPrivacyOptionsRequired] first to avoid
  /// showing this entry point when it can't do anything.
  void showPrivacyOptionsForm(void Function(FormError? error)? onDismissed) {
    try {
      ConsentForm.showPrivacyOptionsForm((error) => onDismissed?.call(error));
    } catch (e, stackTrace) {
      _logger.severe('showPrivacyOptionsForm threw unexpectedly', e, stackTrace);
      onDismissed?.call(FormError(errorCode: 0, message: e.toString()));
    }
  }
}
