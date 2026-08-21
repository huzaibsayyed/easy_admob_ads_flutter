import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'ad_type.dart';
import 'ads/easy_app_open_ad.dart';
import 'ads_config.dart';
import 'app_lifecycle_reactor.dart';
import 'consent/easy_att_manager.dart';
import 'consent/easy_consent_manager.dart';

/// The single entry point for this package: configuration, consent, the
/// Mobile Ads SDK and the App Open ad are all managed from here.
///
/// ```dart
/// await EasyAdMobAds.instance.initialize(
///   config: const EasyAdsConfig(
///     androidAdUnitIds: {AdType.banner: 'ca-app-pub-.../...'},
///     iosAdUnitIds: {AdType.banner: 'ca-app-pub-.../...'},
///   ),
/// );
/// ```
class EasyAdMobAds {
  EasyAdMobAds._();

  /// The single shared instance.
  static final EasyAdMobAds instance = EasyAdMobAds._();

  static final Logger _logger = Logger('EasyAdMobAds');

  static const String _hasLaunchedBeforeKey = 'easy_admob_ads_flutter.has_launched_before';

  final EasyConsentManager _consentManager = EasyConsentManager();
  final EasyAttManager _attManager = EasyAttManager();

  EasyAdsConfig _config = const EasyAdsConfig();
  bool _initialized = false;
  bool _isFirstTimeUser = false;

  final ValueNotifier<bool> _adsEnabled = ValueNotifier<bool>(true);

  /// Turn all ads on/off at runtime, e.g. for a "remove ads" purchase.
  /// `EasyBannerAd`/`EasyNativeAd` listen to this and hide/reload immediately.
  bool get adsEnabled => _adsEnabled.value;
  set adsEnabled(bool value) => _adsEnabled.value = value;

  /// Notifies listeners whenever [adsEnabled] changes.
  ValueListenable<bool> get adsEnabledListenable => _adsEnabled;

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> _hasConnectivity = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Whether the device currently reports a network connection (Wi-Fi/cellular/etc).
  /// This only reflects radio status, not true internet reachability, but it's
  /// enough to avoid firing ad requests you already know will fail while offline.
  bool get hasConnectivity => _hasConnectivity.value;

  /// Notifies listeners whenever [hasConnectivity] changes.
  ValueListenable<bool> get hasConnectivityListenable => _hasConnectivity;

  /// Whether the "privacy options" entry point must be shown to this user (EEA/GDPR).
  bool isPrivacyOptionsRequired = false;

  /// The user's App Tracking Transparency (ATT) choice, set during [initialize]
  /// (only when `EasyAdsConfig.requestTrackingAuthorization` is true). Always
  /// [TrackingStatus.notSupported] on Android and on iOS below 14.0.
  TrackingStatus trackingAuthorizationStatus = TrackingStatus.notDetermined;

  /// Whether this is the very first time the app has ever been launched on
  /// this device (persisted across restarts via `shared_preferences`, so it's
  /// only true once, on the first launch after install). Set during
  /// [initialize]; use it for any first-run-only logic (ads, onboarding, promos, etc.).
  bool get isFirstTimeUser => _isFirstTimeUser;

  AppLifecycleReactor? _lifecycleReactor;

  /// The preloaded App Open ad controller, available once [initialize] has
  /// finished (only when `EasyAdsConfig.preloadAppOpenAd` is true).
  EasyAppOpenAd? appOpenAd;

  /// The config passed to [initialize].
  EasyAdsConfig get config => _config;

  bool get isInitialized => _initialized;

  /// Call once in `main()`, before `runApp()`, after `WidgetsFlutterBinding.ensureInitialized()`.
  ///
  /// This requests GDPR/UMP consent, initializes the Mobile Ads SDK (only if
  /// the user is allowed to be shown ads) and preloads the App Open ad.
  Future<void> initialize({required EasyAdsConfig config}) async {
    if (_initialized) {
      _logger.warning('EasyAdMobAds is already initialized — ignoring duplicate call.');
      return;
    }

    _config = config;
    adsEnabled = config.adsEnabledByDefault;

    final prefs = await SharedPreferences.getInstance();
    _isFirstTimeUser = !(prefs.getBool(_hasLaunchedBeforeKey) ?? false);
    if (_isFirstTimeUser) await prefs.setBool(_hasLaunchedBeforeKey, true);

    _hasConnectivity.value = _isConnected(await _connectivity.checkConnectivity());
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _hasConnectivity.value = _isConnected(result);
    });

    await _consentManager.requestConsent(simulateEeaConsentInDebug: config.simulateEeaConsentInDebug);
    isPrivacyOptionsRequired = await _consentManager.isPrivacyOptionsRequired();

    if (!await _consentManager.canRequestAds()) {
      _logger.warning('User has not consented to ads — the Mobile Ads SDK will not be initialized.');
      return;
    }

    if (config.requestTrackingAuthorization) {
      trackingAuthorizationStatus = await _attManager.requestTrackingAuthorization(settleDelay: config.trackingAuthorizationSettleDelay);
    } else {
      trackingAuthorizationStatus = await _attManager.status;
    }

    await MobileAds.instance.initialize();

    if (kDebugMode && config.testDeviceIds.isNotEmpty) {
      MobileAds.instance.updateRequestConfiguration(RequestConfiguration(testDeviceIds: config.testDeviceIds));
    }

    if (config.preloadAppOpenAd) {
      final appOpenAd = EasyAppOpenAd();
      this.appOpenAd = appOpenAd;
      await appOpenAd.loadAd();
      _lifecycleReactor = AppLifecycleReactor(appOpenAd: appOpenAd)..start();
    }

    _initialized = true;
    _logger.info('EasyAdMobAds initialized successfully.');
  }

  /// Resolves the ad unit ID configured for [type] on the current platform.
  /// Falls back to a Google test ad unit ID (with a warning) if none was configured.
  String adUnitId(AdType type) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Unsupported platform for AdMob ads: $defaultTargetPlatform');
    }

    final configured = Platform.isIOS ? _config.iosAdUnitIds[type] : _config.androidAdUnitIds[type];
    if (configured != null && configured.isNotEmpty) return configured;

    final message = 'No ad unit ID configured for $type on ${Platform.isIOS ? 'iOS' : 'Android'} — using a Google test ad unit ID, which earns no revenue. Set one in EasyAdsConfig before release.';
    _logger.warning(message);
    if (!kDebugMode) {
      // Surfaces in crash-reporting tools even in release builds, since this type would otherwise silently earn $0 forever.
      FlutterError.reportError(FlutterErrorDetails(exception: StateError(message), library: 'easy_admob_ads_flutter'));
    }
    return Platform.isIOS ? kTestAdUnitIdsIOS[type]! : kTestAdUnitIdsAndroid[type]!;
  }

  /// Shows the privacy options form so users can change their consent choice.
  void showPrivacyOptionsForm({void Function(FormError? error)? onDismissed}) {
    _consentManager.showPrivacyOptionsForm(onDismissed);
  }

  static bool _isConnected(List<ConnectivityResult> results) => results.any((result) => result != ConnectivityResult.none);

  /// Releases the preloaded App Open ad and stops listening for app lifecycle/connectivity changes.
  void dispose() {
    _lifecycleReactor?.stop();
    _connectivitySubscription?.cancel();
    appOpenAd?.dispose();
  }
}
