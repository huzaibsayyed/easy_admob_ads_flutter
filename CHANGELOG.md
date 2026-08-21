## 2.0.1

* Fixed static analysis lint issues.
* Applied Dart formatting for improved pub.dev quality score.

## 2.0.0

* **Breaking:** Rewritten package architecture. `EasyAdMobAds` is now the single entry point/facade, replacing `AdmobService`, `AdHelper`, and `AdIdRegistry`.
* **Breaking:** `AdmobConfig` replaced by `EasyAdsConfig`.
* **Breaking:** Ad widgets renamed for consistency: `AdmobBannerAd` → `EasyBannerAd`, `AdmobInterstitial` → `EasyInterstitialAd`, `AdmobRewardedAd` → `EasyRewardedAd`, `AdmobRewardedInterstitialAd` → `EasyRewardedInterstitialAd`, `AdmobNativeAd` → `EasyNativeAd`, `AdmobAppOpenAd` → `EasyAppOpenAd`.
* **Breaking:** `AdmobConsentManager` replaced by `EasyConsentManager`; App Tracking Transparency handling split out into a new `EasyAttManager`.
* Added `AdConfigDiagnostics` to help validate ad unit/config setup.
* Added internal retry/cooldown handling (`AdRetryScheduler`, `AdCooldownTracker`) for more resilient ad loading.
* Added `connectivity_plus` dependency and now re-exports `logging` and `TrackingStatus` from `app_tracking_transparency`.
* Migrated the example app's iOS project from CocoaPods to Swift Package Manager.

## 1.0.4

* Dependencies updated: `google_mobile_ads`

## 1.0.3

* Dependencies updated: `google_mobile_ads` and `shared_preferences`

## 1.0.2

* Dependencies updated: `google_mobile_ads` and `shared_preferences`

## 1.0.1

* Removed the loading spinner for both banner and native ads

## 1.0.0

* Updated GDPR Settings Button in README

## 0.0.9

* Added support for Immersive Mode on Android: Interstitial ads, Rewarded ads, Rewarded interstitial ads
* Fixed `AdState`: Added disabled state when `showAds = false` globally

## 0.0.8

* Added Collapsible feature for Banner Ads

## 0.0.7

* Fixed App Open Ad issue with real background time difference check

## 0.0.6

* Removed test ID bug
* Updated README.md
* Added consent handling with global `isPrivacyOptionRequired` variable
* Added `logging` package

## 0.0.5

* Files formatted

## 0.0.4

* Added screenshots to README.md

## 0.0.3

* Added screenshots and improved Example App UI

## 0.0.2

* Added GDPR Consent

## 0.0.1

* Added `google_mobile_ads: ^6.0.0` and `shared_preferences: ^2.5.3`
* Added ad formats: Banner, Interstitial, Rewarded, Rewarded Interstitial, App Open, Native