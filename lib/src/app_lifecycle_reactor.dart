import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'ads/easy_app_open_ad.dart';

/// Watches app foreground/background transitions and shows the App Open ad
/// when the app returns to the foreground after a real background stay
/// (short interruptions like the share sheet or a permission dialog are ignored).
class AppLifecycleReactor extends WidgetsBindingObserver {
  static final Logger _logger = Logger('AppLifecycleReactor');

  final EasyAppOpenAd appOpenAd;
  final Duration minimumBackgroundDuration;

  DateTime? _backgroundEnterTime;

  AppLifecycleReactor({required this.appOpenAd, this.minimumBackgroundDuration = const Duration(minutes: 2)});

  void start() => WidgetsBinding.instance.addObserver(this);

  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();

    if (state == AppLifecycleState.paused) {
      _backgroundEnterTime = now;
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    final enteredAt = _backgroundEnterTime;
    _backgroundEnterTime = null;
    if (enteredAt == null) return;

    final backgroundDuration = now.difference(enteredAt);
    if (backgroundDuration < minimumBackgroundDuration) return;

    _logger.fine('Returned from background after ${backgroundDuration.inSeconds}s — showing App Open ad if available.');
    appOpenAd.showAdIfAvailable();
  }
}
