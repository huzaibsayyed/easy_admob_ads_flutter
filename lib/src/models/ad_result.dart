class AdResult {
  final bool wasShown;
  final String message;
  final AdFailReason? failReason;

  const AdResult({required this.wasShown, required this.message, this.failReason});

  @override
  String toString() => 'AdResult(wasShown: $wasShown, message: "$message", failReason: $failReason)';
}

enum AdFailReason { adsDisabled, cooldownPeriod, notLoaded, showError, firstEverOpen }
