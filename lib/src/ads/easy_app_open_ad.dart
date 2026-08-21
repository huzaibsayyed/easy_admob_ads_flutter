import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

import '../ad_config_diagnostics.dart';
import '../ad_result.dart';
import '../ad_state.dart';
import '../ad_type.dart';
import '../easy_admob_ads.dart';
import '../internal/ad_cooldown_tracker.dart';
import '../internal/ad_retry_scheduler.dart';

/// Controller for a Google AdMob App Open ad.
///
/// Usually you don't create this yourself — [EasyAdMobAds.initialize] creates
/// and preloads one for you when `EasyAdsConfig.preloadAppOpenAd` is true, and
/// automatically shows it when the app returns to the foreground. Access it
/// via [EasyAdMobAds.appOpenAd] if you want to show it manually too.
class EasyAppOpenAd with AdRetryScheduler, AdCooldownTracker {
  static final Logger _logger = Logger('EasyAppOpenAd');

  AppOpenAd? _ad;
  AdState _state = AdState.initial;
  DateTime? _loadTime;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  bool _isFirstAppOpen = true;
  Completer<AdResult>? _showCompleter;

  /// Called whenever the ad's [AdState] changes.
  void Function(AdState state)? onStateChanged;

  EasyAppOpenAd() {
    EasyAdMobAds.instance.hasConnectivityListenable.addListener(_onConnectivityChanged);
    EasyAdMobAds.instance.adsEnabledListenable.addListener(_onAdsEnabledChanged);
  }

  AdState get state => _state;

  bool get isReady => _ad != null && !_isExpired && !_isShowingAd;

  void _setState(AdState state) {
    _state = state;
    onStateChanged?.call(state);
  }

  // Retries right away once the device comes back online instead of waiting for the retry timer.
  void _onConnectivityChanged() {
    if (isDisposed) return;
    if (EasyAdMobAds.instance.hasConnectivity && _ad == null && !_isLoadingAd) {
      loadAd();
    }
  }

  // Loads right away once ads are turned back on, instead of staying unloaded until the next resume/retry.
  void _onAdsEnabledChanged() {
    if (isDisposed) return;
    if (EasyAdMobAds.instance.adsEnabled && _ad == null && !_isLoadingAd) {
      loadAd();
    }
  }

  bool get _isExpired {
    final loadTime = _loadTime;
    if (loadTime == null) return true;
    return DateTime.now().difference(loadTime) > EasyAdMobAds.instance.config.appOpenAdMaxCacheAge;
  }

  Future<void> loadAd() async {
    final ads = EasyAdMobAds.instance;

    // Checked synchronously, before any await, so concurrent calls can't both proceed.
    if (!ads.adsEnabled || _isShowingAd || _isLoadingAd) return;
    if (_ad != null && !_isExpired) return;

    if (!ads.hasConnectivity) {
      _logger.fine('No network connectivity. App Open ad will not load yet.');
      _isFirstAppOpen = false;
      _setState(AdState.error);
      scheduleRetry(ads.config.retryDelay, loadAd);
      return;
    }

    _isLoadingAd = true;
    _setState(AdState.loading);

    try {
      await AppOpenAd.load(
        adUnitId: ads.adUnitId(AdType.appOpen),
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingAd = false;
            if (isDisposed) {
              ad.dispose();
              return;
            }

            _ad?.dispose(); // Replace any stale instance rather than leaking it.
            _ad = ad;
            _loadTime = DateTime.now();
            _setState(AdState.loaded);
            _logger.info('App Open ad loaded.');

            final showOnFirstLaunch = _isFirstAppOpen && ads.config.showAppOpenAdOnFirstLaunch;
            _isFirstAppOpen = false;
            if (showOnFirstLaunch) {
              // Small delay so the ad doesn't flash in before the app's first frame settles.
              Future.delayed(ads.config.appOpenAdInitialLoadTimeout, showAdIfAvailable);
            }
          },
          onAdFailedToLoad: (error) {
            _isLoadingAd = false;
            _isFirstAppOpen = false;
            _setState(AdState.error);
            AdConfigDiagnostics.check(error, adUnitId: ads.adUnitId(AdType.appOpen), adType: 'App Open');
            scheduleRetry(ads.config.retryDelay, loadAd);
          },
        ),
      );
    } catch (e) {
      _isLoadingAd = false;
      _isFirstAppOpen = false;
      _setState(AdState.error);
      _logger.severe('Error loading App Open ad: $e');
    }
  }

  Future<AdResult> showAdIfAvailable() async {
    final ads = EasyAdMobAds.instance;

    if (!ads.adsEnabled) {
      return const AdResult(wasShown: false, message: 'Ads are disabled globally', failReason: AdFailReason.adsDisabled);
    }
    if (ads.config.skipAppOpenAdForFirstTimeUser && ads.isFirstTimeUser) {
      return const AdResult(wasShown: false, message: 'Skipped for first-time user', failReason: AdFailReason.firstTimeUser);
    }
    if (_isShowingAd) {
      return const AdResult(wasShown: false, message: 'An ad is already being shown', failReason: AdFailReason.showError);
    }

    final cooldown = ads.config.appOpenAdCooldown;
    if (isCooldownActive(cooldown)) {
      final secondsLeft = remainingCooldown(cooldown).inSeconds;
      _logger.warning('Not enough time passed since last ad. Try again in $secondsLeft seconds');
      return AdResult(wasShown: false, message: 'Not enough time passed since last ad. Try again in $secondsLeft seconds', failReason: AdFailReason.cooldownPeriod);
    }

    if (_ad == null || _isExpired) {
      loadAd();
      return const AdResult(wasShown: false, message: 'App Open ad not ready yet', failReason: AdFailReason.notLoaded);
    }

    final ad = _ad!;
    try {
      _isShowingAd = true;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) => _logger.fine('App Open ad shown.'),
        onAdFailedToShowFullScreenContent: (ad, error) {
          _logger.warning('App Open ad failed to show: ${error.message}');
          _isShowingAd = false;
          ad.dispose();
          _ad = null;
          _setState(AdState.error);
          scheduleRetry(ads.config.retryDelay, loadAd);
          _showCompleter?.complete(AdResult(wasShown: false, message: 'Error showing App Open ad: ${error.message}', failReason: AdFailReason.showError));
          _showCompleter = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          _logger.info('App Open ad dismissed.');
          _isShowingAd = false;
          markShownNow();
          ad.dispose();
          _ad = null;
          _setState(AdState.closed);
          loadAd();
          _showCompleter?.complete(const AdResult(wasShown: true, message: 'App Open ad shown successfully'));
          _showCompleter = null;
        },
        onAdImpression: (ad) => _logger.fine('App Open ad impression recorded.'),
      );

      final completer = Completer<AdResult>();
      _showCompleter = completer;
      await ad.show();
      // Resolves once onAdDismissedFullScreenContent/onAdFailedToShowFullScreenContent
      // fires, not when the above call returns — show() only confirms the ad was
      // requested to display.
      return await completer.future;
    } catch (e) {
      _logger.severe('Error showing App Open ad: $e');
      _isShowingAd = false;
      ad.dispose();
      _ad = null;
      loadAd();
      return AdResult(wasShown: false, message: 'Error showing App Open ad: $e', failReason: AdFailReason.showError);
    }
  }

  void dispose() {
    EasyAdMobAds.instance.hasConnectivityListenable.removeListener(_onConnectivityChanged);
    EasyAdMobAds.instance.adsEnabledListenable.removeListener(_onAdsEnabledChanged);
    disposeRetryScheduler();
    _ad?.dispose();
    _ad = null;
    if (_showCompleter case final completer? when !completer.isCompleted) {
      completer.complete(const AdResult(wasShown: false, message: 'Ad controller disposed while showing', failReason: AdFailReason.showError));
    }
    _showCompleter = null;
  }
}
