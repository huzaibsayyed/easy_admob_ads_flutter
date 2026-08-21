import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

import '../ad_config_diagnostics.dart';
import '../ad_state.dart';
import '../ad_type.dart';
import '../easy_admob_ads.dart';

/// A ready-to-use AdMob native ad, rendered with Google's pre-built templates.
///
/// Use the [EasyNativeAd.small] or [EasyNativeAd.medium] factories for common sizes.
class EasyNativeAd extends StatefulWidget {
  final double height;
  final void Function(AdState state)? onStateChanged;
  final NativeTemplateStyle templateStyle;

  const EasyNativeAd({super.key, required this.height, required this.templateStyle, this.onStateChanged});

  factory EasyNativeAd.small({Key? key, double height = 120.0, void Function(AdState state)? onStateChanged, Color backgroundColor = Colors.white, double cornerRadius = 8.0}) {
    return EasyNativeAd(
      key: key,
      height: height,
      onStateChanged: onStateChanged,
      templateStyle: NativeTemplateStyle(templateType: TemplateType.small, mainBackgroundColor: backgroundColor, cornerRadius: cornerRadius),
    );
  }

  factory EasyNativeAd.medium({Key? key, double height = 320.0, void Function(AdState state)? onStateChanged, Color backgroundColor = Colors.white, double cornerRadius = 8.0}) {
    return EasyNativeAd(
      key: key,
      height: height,
      onStateChanged: onStateChanged,
      templateStyle: NativeTemplateStyle(templateType: TemplateType.medium, mainBackgroundColor: backgroundColor, cornerRadius: cornerRadius),
    );
  }

  @override
  State<EasyNativeAd> createState() => _EasyNativeAdState();
}

class _EasyNativeAdState extends State<EasyNativeAd> {
  static final Logger _logger = Logger('EasyNativeAd');

  NativeAd? _ad;
  AdState _state = AdState.initial;
  bool _isLoaded = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    EasyAdMobAds.instance.adsEnabledListenable.addListener(_onAdsEnabledChanged);
    EasyAdMobAds.instance.hasConnectivityListenable.addListener(_onConnectivityChanged);

    if (EasyAdMobAds.instance.adsEnabled) {
      _loadAd();
    } else {
      _state = AdState.disabled;
      widget.onStateChanged?.call(AdState.disabled);
    }
  }

  // Rebuilds to hide the ad immediately when turned off, and loads one if turned back on.
  void _onAdsEnabledChanged() {
    if (!mounted) return;
    if (EasyAdMobAds.instance.adsEnabled && _ad == null) _loadAd();
    setState(() {});
  }

  // Retries right away once the device comes back online instead of waiting for the retry timer.
  void _onConnectivityChanged() {
    if (!mounted) return;
    if (EasyAdMobAds.instance.hasConnectivity && _ad == null) _loadAd();
  }

  void _loadAd() {
    final ads = EasyAdMobAds.instance;

    if (!ads.hasConnectivity) {
      _logger.fine('No network connectivity. Native ad will not load yet.');
      setState(() {
        _state = AdState.error;
        _isLoaded = false;
      });
      widget.onStateChanged?.call(AdState.error);
      _retryTimer?.cancel();
      _retryTimer = Timer(ads.config.retryDelay, () {
        if (mounted && ads.adsEnabled) _loadAd();
      });
      return;
    }

    _logger.info('Loading native ad...');

    setState(() {
      _state = AdState.loading;
      _isLoaded = false;
    });
    widget.onStateChanged?.call(AdState.loading);

    _ad = NativeAd(
      adUnitId: ads.adUnitId(AdType.native),
      nativeTemplateStyle: widget.templateStyle,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _logger.info('Native ad loaded.');
          if (!mounted) return;
          setState(() {
            _state = AdState.loaded;
            _isLoaded = true;
            _retryAttempt = 0;
          });
          widget.onStateChanged?.call(AdState.loaded);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _logger.warning('Native ad failed to load: ${error.message}');
          AdConfigDiagnostics.check(error, adUnitId: ads.adUnitId(AdType.native), adType: 'Native');

          if (mounted) {
            setState(() {
              _state = AdState.error;
              _isLoaded = false;
            });
            widget.onStateChanged?.call(AdState.error);
          }

          if (_retryAttempt < ads.config.maxRetryAttempts) {
            _retryAttempt++;
            _retryTimer?.cancel();
            _retryTimer = Timer(ads.config.retryDelay, () {
              if (mounted) _loadAd();
            });
          }
        },
        onAdOpened: (_) => _logger.fine('Native ad opened.'),
        onAdClosed: (_) => _logger.fine('Native ad closed.'),
        onAdImpression: (_) => _logger.fine('Native ad impression recorded.'),
        onAdClicked: (_) => _logger.fine('Native ad clicked.'),
      ),
    );

    _ad?.load();
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
    if (_state != AdState.loaded || !_isLoaded || _ad == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height,
      child: AdWidget(ad: _ad!),
    );
  }
}
