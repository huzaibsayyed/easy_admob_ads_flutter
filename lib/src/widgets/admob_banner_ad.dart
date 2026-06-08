import 'dart:async';

import 'package:easy_admob_ads_flutter/src/ad_exceptions.dart';
import 'package:easy_admob_ads_flutter/src/ad_helper.dart';
import 'package:easy_admob_ads_flutter/src/models/ad_state.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logging/logging.dart';

class AdmobBannerAd extends StatefulWidget {
  final bool collapsible;
  final double? height;
  final void Function(AdState state)? onAdStateChanged;

  const AdmobBannerAd({super.key, this.collapsible = false, this.height, this.onAdStateChanged});

  @override
  // ignore: library_private_types_in_public_api
  _AdmobBannerAdState createState() => _AdmobBannerAdState();
}

class _AdmobBannerAdState extends State<AdmobBannerAd> {
  static final Logger _logger = Logger('AdmobBannerAd');
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  AdSize? _adSize;
  int _retryCount = 0;
  final int _maxRetries = 3;
  Timer? _retryTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AdHelper.showAds) {
      _loadBannerAd();
    }
  }

  Future<void> _loadBannerAd() async {
    if (_bannerAd != null || _isAdLoaded) return;

    final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(MediaQuery.of(context).size.width.truncate());

    if (adSize == null) {
      _logger.warning('⚠️ Adaptive ad size not available.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _adSize = adSize;
    });

    final adRequest = widget.collapsible ? const AdRequest(extras: {"collapsible": "bottom"}) : const AdRequest();

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: adSize,
      request: adRequest,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (_isAdLoaded) return; // Prevent double handling
          _logger.info('✅ Banner ad loaded.');
          _retryTimer?.cancel();
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
          widget.onAdStateChanged?.call(AdState.loaded);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          _logger.warning('❌ Banner ad failed: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() => _isAdLoaded = false);
          }
          widget.onAdStateChanged?.call(AdState.error);
          AdException.check(error, adUnitId: AdHelper.bannerAdUnitId, adType: "Banner Ad");

          // Retry if under limit
          if (_retryCount < _maxRetries) {
            _retryTimer?.cancel();
            _retryTimer = Timer(const Duration(seconds: 30), () {
              if (mounted && AdHelper.showAds) {
                _retryCount++;
                _logger.info('🔁 Retrying banner ad ($_retryCount/$_maxRetries)...');
                _bannerAd = null;
                _loadBannerAd();
              }
            });
          } else {
            _logger.warning('🛑 Max retry attempts reached.');
          }
        },
        onAdOpened: (_) => _logger.fine('🔓 Banner ad opened'),
        onAdClosed: (_) => _logger.fine('🔒 Banner ad closed'),
        onAdImpression: (_) => _logger.fine('📊 Banner ad impression'),
        onAdClicked: (_) => _logger.fine('🖱️ Banner ad clicked'),
      ),
    );

    await _bannerAd?.load();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdHelper.showAds) {
      _logger.fine('Ads are disabled. Banner ad will not load.');
      return const SizedBox.shrink();
    }

    final isLoading = !_isAdLoaded || _bannerAd == null || _adSize == null;

    if (isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      height: widget.height ?? _adSize!.height.toDouble(),
      width: _adSize!.width.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
