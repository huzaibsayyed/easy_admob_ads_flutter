/// The outcome of a call to `showAd()` on any full-screen ad controller.
class AdResult {
  final bool wasShown;
  final String message;
  final AdFailReason? failReason;

  const AdResult({required this.wasShown, required this.message, this.failReason});

  @override
  String toString() => 'AdResult(wasShown: $wasShown, message: "$message", failReason: $failReason)';
}

/// Why an ad was not shown when `showAd()` was called.
enum AdFailReason { adsDisabled, cooldownPeriod, notLoaded, showError, firstTimeUser }
