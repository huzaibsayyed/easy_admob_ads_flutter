import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:logging/logging.dart';

/// Wraps Apple's App Tracking Transparency (ATT) framework so AdMob can use
/// IDFA-based targeting on iOS 14.5+.
///
/// You normally don't need to use this directly — [EasyAdMobAds.initialize]
/// calls it for you (after GDPR/UMP consent, before the Mobile Ads SDK is
/// initialized) when `EasyAdsConfig.requestTrackingAuthorization` is true.
/// No-ops on every platform other than iOS.
///
/// Requires `NSUserTrackingUsageDescription` to be set in `ios/Runner/Info.plist`.
class EasyAttManager {
  static final Logger _logger = Logger('EasyAttManager');

  /// The current authorization status, without prompting the user.
  Future<TrackingStatus> get status async {
    if (!Platform.isIOS) return TrackingStatus.notSupported;
    return AppTrackingTransparency.trackingAuthorizationStatus;
  }

  /// Shows the system tracking-authorization dialog if it hasn't been
  /// resolved yet, waiting [settleDelay] first so it doesn't collide with
  /// any UI transition still in flight (Apple drops a dialog request if
  /// another one is already animating on/off screen).
  ///
  /// No-ops on non-iOS platforms.
  Future<TrackingStatus> requestTrackingAuthorization({Duration settleDelay = const Duration(milliseconds: 200)}) async {
    if (!Platform.isIOS) return TrackingStatus.notSupported;

    final current = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (current != TrackingStatus.notDetermined) return current;

    if (settleDelay > Duration.zero) await Future.delayed(settleDelay);

    final status = await AppTrackingTransparency.requestTrackingAuthorization();
    _logger.info('App Tracking Transparency status: $status');
    return status;
  }
}
