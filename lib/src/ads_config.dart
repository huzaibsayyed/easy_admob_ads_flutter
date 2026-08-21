import 'ad_type.dart';

/// All the tunable knobs for this package, gathered in one place.
///
/// Pass this to [EasyAdMobAds.initialize]. Every field has a sensible default,
/// so you only need to set the ad unit IDs you actually use.
class EasyAdsConfig {
  /// Android ad unit IDs, keyed by [AdType]. Leave a type out to use a
  /// Google test ad unit ID for it (a warning is logged when that happens).
  final Map<AdType, String> androidAdUnitIds;

  /// iOS ad unit IDs, keyed by [AdType]. Leave a type out to use a
  /// Google test ad unit ID for it (a warning is logged when that happens).
  final Map<AdType, String> iosAdUnitIds;

  /// Device IDs that should always receive test ads (only applied in debug builds).
  final List<String> testDeviceIds;

  /// Initial value of [EasyAdMobAds.adsEnabled].
  final bool adsEnabledByDefault;

  /// Whether to load an App Open ad during [EasyAdMobAds.initialize] and
  /// automatically show it when the app returns to the foreground.
  final bool preloadAppOpenAd;

  /// Whether the App Open ad may also be shown right after it finishes
  /// loading for the very first time in this app session (e.g. on a cold start).
  final bool showAppOpenAdOnFirstLaunch;

  /// Whether the App Open ad should never be shown to a first-time user, i.e.
  /// the very first time the app is ever launched on this device after install
  /// (see `EasyAdMobAds.isFirstTimeUser`, persisted across restarts). Applies
  /// to every `showAdIfAvailable()` call, not just the automatic cold-start one.
  final bool skipAppOpenAdForFirstTimeUser;

  /// Simulates an EEA (GDPR) user in debug builds so you can test the consent flow.
  final bool simulateEeaConsentInDebug;

  /// Whether to request App Tracking Transparency (ATT) authorization on iOS
  /// 14.5+ during [EasyAdMobAds.initialize], after GDPR/UMP consent and before
  /// the Mobile Ads SDK is initialized. Requires `NSUserTrackingUsageDescription`
  /// to be set in `ios/Runner/Info.plist`. Ignored on other platforms.
  final bool requestTrackingAuthorization;

  /// Delay before showing the ATT system dialog, so it doesn't collide with
  /// any UI transition still in flight (Apple drops a dialog request if
  /// another one is already animating on/off screen).
  final Duration trackingAuthorizationSettleDelay;

  /// Whether full-screen ads should use Android's immersive mode.
  final bool immersiveModeEnabled;

  final Duration interstitialCooldown;
  final Duration rewardedCooldown;
  final Duration rewardedInterstitialCooldown;
  final Duration appOpenAdCooldown;

  /// App Open ads older than this are considered stale and are reloaded.
  final Duration appOpenAdMaxCacheAge;

  /// Delay before auto-showing an App Open ad loaded on first launch (see [showAppOpenAdOnFirstLaunch]).
  final Duration appOpenAdInitialLoadTimeout;

  /// Delay before retrying a failed load/show across all ad types.
  final Duration retryDelay;

  /// Max retry attempts for Banner/Native ad widgets (full-screen ads retry indefinitely).
  final int maxRetryAttempts;

  const EasyAdsConfig({
    this.androidAdUnitIds = const {},
    this.iosAdUnitIds = const {},
    this.testDeviceIds = const [],
    this.adsEnabledByDefault = true,
    this.preloadAppOpenAd = true,
    this.showAppOpenAdOnFirstLaunch = true,
    this.skipAppOpenAdForFirstTimeUser = true,
    this.simulateEeaConsentInDebug = false,
    this.requestTrackingAuthorization = true,
    this.trackingAuthorizationSettleDelay = const Duration(milliseconds: 200),
    this.immersiveModeEnabled = true,
    this.interstitialCooldown = const Duration(seconds: 30),
    this.rewardedCooldown = const Duration(seconds: 10),
    this.rewardedInterstitialCooldown = const Duration(seconds: 10),
    this.appOpenAdCooldown = const Duration(minutes: 1),
    this.appOpenAdMaxCacheAge = const Duration(hours: 4),
    this.appOpenAdInitialLoadTimeout = const Duration(milliseconds: 800),
    this.retryDelay = const Duration(seconds: 30),
    this.maxRetryAttempts = 3,
  });
}

/// Google's official test ad unit IDs — https://developers.google.com/admob/flutter/test-ads
const Map<AdType, String> kTestAdUnitIdsAndroid = {
  AdType.banner: 'ca-app-pub-3940256099942544/9214589741',
  AdType.interstitial: 'ca-app-pub-3940256099942544/1033173712',
  AdType.rewarded: 'ca-app-pub-3940256099942544/5224354917',
  AdType.rewardedInterstitial: 'ca-app-pub-3940256099942544/5354046379',
  AdType.appOpen: 'ca-app-pub-3940256099942544/9257395921',
  AdType.native: 'ca-app-pub-3940256099942544/2247696110',
};

const Map<AdType, String> kTestAdUnitIdsIOS = {
  AdType.banner: 'ca-app-pub-3940256099942544/2435281174',
  AdType.interstitial: 'ca-app-pub-3940256099942544/4411468910',
  AdType.rewarded: 'ca-app-pub-3940256099942544/1712485313',
  AdType.rewardedInterstitial: 'ca-app-pub-3940256099942544/6978759866',
  AdType.appOpen: 'ca-app-pub-3940256099942544/5575463023',
  AdType.native: 'ca-app-pub-3940256099942544/3986624511',
};
