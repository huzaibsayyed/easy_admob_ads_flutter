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

/// Controller for a Google AdMob Rewarded ad.
///
/// ```dart
/// final ad = EasyRewardedAd(onRewardEarned: (reward) => grantCoins(reward.amount));
/// await ad.loadAd();
/// // later
/// final result = await ad.showAd();
/// ```
class EasyRewardedAd with AdRetryScheduler, AdCooldownTracker {
  static final Logger _logger = Logger('EasyRewardedAd');

  RewardedAd? _ad;
  AdState _state = AdState.initial;
  Completer<AdResult>? _showCompleter;

  final void Function(AdState state)? onStateChanged;
  final void Function(RewardItem reward)? onRewardEarned;

  EasyRewardedAd({this.onStateChanged, this.onRewardEarned}) {
    EasyAdMobAds.instance.hasConnectivityListenable.addListener(_onConnectivityChanged);
    EasyAdMobAds.instance.adsEnabledListenable.addListener(_onAdsEnabledChanged);
  }

  AdState get state => _state;

  bool get isReady => _state == AdState.loaded && _ad != null;

  void _setState(AdState state) {
    _state = state;
    onStateChanged?.call(state);
  }

  // Retries right away once the device comes back online instead of waiting for the retry timer.
  void _onConnectivityChanged() {
    if (isDisposed) return;
    if (EasyAdMobAds.instance.hasConnectivity && _ad == null && _state != AdState.loading) loadAd();
  }

  // Loads right away once ads are turned back on, instead of staying stuck in AdState.disabled.
  void _onAdsEnabledChanged() {
    if (isDisposed) return;
    if (EasyAdMobAds.instance.adsEnabled && _ad == null && _state != AdState.loading) loadAd();
  }

  Future<void> loadAd() async {
    final ads = EasyAdMobAds.instance;

    if (!ads.adsEnabled) {
      _logger.fine('Ads are disabled globally. Rewarded ad will not load.');
      _setState(AdState.disabled);
      return;
    }

    if (_state == AdState.loading || _state == AdState.loaded) {
      _logger.fine('Rewarded ad already loading or loaded. Skipping new load request.');
      return;
    }

    final config = ads.config;

    if (!ads.hasConnectivity) {
      _logger.fine('No network connectivity. Rewarded ad will not load yet.');
      _setState(AdState.error);
      scheduleRetry(config.retryDelay, loadAd);
      return;
    }

    _setState(AdState.loading);

    await RewardedAd.load(
      adUnitId: ads.adUnitId(AdType.rewarded),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (isDisposed) {
            ad.dispose();
            return;
          }

          ad.setImmersiveMode(config.immersiveModeEnabled);
          _ad = ad;
          _setState(AdState.loaded);
          _logger.info('Rewarded ad loaded.');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _logger.info('Rewarded ad dismissed.');
              markShownNow();
              ad.dispose();
              _ad = null;
              _setState(AdState.closed);
              loadAd(); // Auto reload for next time
              _showCompleter?.complete(const AdResult(wasShown: true, message: 'Ad shown successfully'));
              _showCompleter = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _logger.warning('Failed to show rewarded ad: ${error.message}');
              ad.dispose();
              _ad = null;
              _setState(AdState.error);
              scheduleRetry(config.retryDelay, loadAd);
              _showCompleter?.complete(AdResult(wasShown: false, message: 'Error showing ad: ${error.message}', failReason: AdFailReason.showError));
              _showCompleter = null;
            },
            onAdShowedFullScreenContent: (ad) => _logger.fine('Rewarded ad shown.'),
            onAdImpression: (ad) => _logger.fine('Rewarded ad impression recorded.'),
          );
        },
        onAdFailedToLoad: (error) {
          _logger.warning('Rewarded ad failed to load: ${error.message}');
          AdConfigDiagnostics.check(error, adUnitId: ads.adUnitId(AdType.rewarded), adType: 'Rewarded');
          _setState(AdState.error);
          scheduleRetry(config.retryDelay, loadAd);
        },
      ),
    );
  }

  Future<AdResult> showAd() async {
    final ads = EasyAdMobAds.instance;

    if (!ads.adsEnabled) {
      return const AdResult(wasShown: false, message: 'Ads are disabled globally', failReason: AdFailReason.adsDisabled);
    }

    final cooldown = ads.config.rewardedCooldown;
    if (isCooldownActive(cooldown)) {
      final secondsLeft = remainingCooldown(cooldown).inSeconds;
      _logger.warning('Not enough time passed since last ad. Try again in $secondsLeft seconds');
      return AdResult(wasShown: false, message: 'Not enough time passed since last ad. Try again in $secondsLeft seconds', failReason: AdFailReason.cooldownPeriod);
    }

    if (_ad == null || _state != AdState.loaded) {
      return AdResult(wasShown: false, message: 'Ad not ready yet. Current state: $_state', failReason: AdFailReason.notLoaded);
    }

    try {
      final completer = Completer<AdResult>();
      _showCompleter = completer;
      await _ad!.show(
        onUserEarnedReward: (_, reward) {
          _logger.info('User earned reward: ${reward.amount} ${reward.type}');
          onRewardEarned?.call(reward);
        },
      );
      // Resolves once onAdDismissedFullScreenContent/onAdFailedToShowFullScreenContent
      // fires, not when the above call returns — show() only confirms the ad was
      // requested to display.
      return await completer.future;
    } catch (e) {
      _logger.severe('Error showing rewarded ad: $e');
      _ad?.dispose();
      _ad = null;
      _setState(AdState.error);
      loadAd(); // Try to load for next time
      return AdResult(wasShown: false, message: 'Error showing ad: $e', failReason: AdFailReason.showError);
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
