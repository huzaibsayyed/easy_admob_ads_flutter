import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

import '../ad_config_diagnostics.dart';
import '../ad_state.dart';
import '../ad_type.dart';
import '../easy_admob_ads.dart';

/// A ready-to-use, adaptively-sized AdMob banner.
///
/// ```dart
/// EasyBannerAd(collapsible: true)
/// ```
class EasyBannerAd extends StatefulWidget {
  /// Shows the banner as a collapsible banner anchored to the bottom.
  final bool collapsible;

  /// Overrides the widget's height (the ad content itself keeps its natural size).
  final double? height;

  final void Function(AdState state)? onStateChanged;

  const EasyBannerAd({super.key, this.collapsible = false, this.height, this.onStateChanged});

  @override
  State<EasyBannerAd> createState() => _EasyBannerAdState();
}

class _EasyBannerAdState extends State<EasyBannerAd> {
  static final Logger _logger = Logger('EasyBannerAd');

  BannerAd? _ad;
  AdSize? _adSize;
  bool _isLoaded = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    EasyAdMobAds.instance.adsEnabledListenable.addListener(_onAdsEnabledChanged);
    EasyAdMobAds.instance.hasConnectivityListenable.addListener(_onConnectivityChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (EasyAdMobAds.instance.adsEnabled) _loadAd();
  }

  // Rebuilds to hide the ad immediately when turned off, and loads one if turned back on.
  void _onAdsEnabledChanged() {
    if (!mounted) return;
    if (EasyAdMobAds.instance.adsEnabled) _loadAd();
    setState(() {});
  }

  // Retries right away once the device comes back online instead of waiting for the retry timer.
  void _onConnectivityChanged() {
    if (!mounted) return;
    if (EasyAdMobAds.instance.hasConnectivity) _loadAd();
  }

  Future<void> _loadAd() async {
    if (_ad != null || _isLoaded) return;

    final ads = EasyAdMobAds.instance;
    if (!ads.hasConnectivity) {
      _logger.fine('No network connectivity. Banner ad will not load yet.');
      _retryTimer?.cancel();
      _retryTimer = Timer(ads.config.retryDelay, () {
        if (mounted && ads.adsEnabled) _loadAd();
      });
      return;
    }

    final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(MediaQuery.sizeOf(context).width.truncate());
    if (adSize == null) {
      _logger.warning('Adaptive banner size unavailable for the current width.');
      return;
    }
    if (!mounted) return;

    setState(() => _adSize = adSize);

    final request = widget.collapsible ? const AdRequest(extras: {'collapsible': 'bottom'}) : const AdRequest();

    _ad = BannerAd(
      adUnitId: ads.adUnitId(AdType.banner),
      size: adSize,
      request: request,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _retryTimer?.cancel();
          _retryAttempt = 0;
          if (mounted) setState(() => _isLoaded = true);
          widget.onStateChanged?.call(AdState.loaded);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _isLoaded = false);
          widget.onStateChanged?.call(AdState.error);
          AdConfigDiagnostics.check(error, adUnitId: ads.adUnitId(AdType.banner), adType: 'Banner');

          if (_retryAttempt < ads.config.maxRetryAttempts) {
            _retryAttempt++;
            _retryTimer?.cancel();
            _retryTimer = Timer(ads.config.retryDelay, () {
              if (mounted && ads.adsEnabled) {
                _ad = null;
                _loadAd();
              }
            });
          }
        },
        onAdOpened: (_) => _logger.fine('Banner ad opened.'),
        onAdClosed: (_) => _logger.fine('Banner ad closed.'),
        onAdImpression: (_) => _logger.fine('Banner ad impression recorded.'),
        onAdClicked: (_) => _logger.fine('Banner ad clicked.'),
      ),
    );

    await _ad?.load();
  }

  @override
  void dispose() {
    EasyAdMobAds.instance.adsEnabledListenable.removeListener(_onAdsEnabledChanged);
    EasyAdMobAds.instance.hasConnectivityListenable.removeListener(_onConnectivityChanged);
    _retryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!EasyAdMobAds.instance.adsEnabled) return const SizedBox.shrink();
    if (!_isLoaded || _ad == null || _adSize == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      height: widget.height ?? _adSize!.height.toDouble(),
      width: _adSize!.width.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
