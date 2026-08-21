/// Tracks the last time an ad was shown so callers can enforce a minimum
/// gap between ads (shared by Interstitial, Rewarded, Rewarded Interstitial and App Open ads).
///
/// Keyed by [runtimeType] rather than kept as a plain instance field: callers
/// typically construct a new `EasyInterstitialAd` (etc.) per page, and the
/// cooldown must still hold across those separate instances of the same ad
/// type — while staying independent from other ad types, which have their
/// own cooldown durations.
mixin AdCooldownTracker {
  static final Map<Type, DateTime> _lastShownAt = {};

  void markShownNow() => _lastShownAt[runtimeType] = DateTime.now();

  bool isCooldownActive(Duration cooldown) {
    final lastShownAt = _lastShownAt[runtimeType];
    return lastShownAt != null && DateTime.now().difference(lastShownAt) < cooldown;
  }

  Duration remainingCooldown(Duration cooldown) {
    final lastShownAt = _lastShownAt[runtimeType];
    if (lastShownAt == null) return Duration.zero;
    final remaining = cooldown - DateTime.now().difference(lastShownAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
