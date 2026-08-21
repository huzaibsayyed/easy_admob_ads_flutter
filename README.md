[![Stand With Palestine](https://raw.githubusercontent.com/TheBSD/StandWithPalestine/main/banner-no-action.svg)](https://thebsd.github.io/StandWithPalestine)

# Easy AdMob Integration for Flutter

[![pub package](https://img.shields.io/pub/v/easy_admob_ads_flutter.svg?logo=dart\&logoColor=00b9fc)](https://pub.dev/packages/easy_admob_ads_flutter)
![Pub Points](https://img.shields.io/pub/points/easy_admob_ads_flutter?label=Pub.dev%20Points)
[![Last Commit](https://img.shields.io/github/last-commit/huzaibsayyed/easy_admob_ads_flutter?logo=git\&logoColor=white)](https://github.com/huzaibsayyed/easy_admob_ads_flutter/commits/main)
[![Pull Requests](https://img.shields.io/github/issues-pr/huzaibsayyed/easy_admob_ads_flutter?logo=github\&logoColor=white)](https://github.com/huzaibsayyed/easy_admob_ads_flutter/pulls)
[![Code Size](https://img.shields.io/github/languages/code-size/huzaibsayyed/easy_admob_ads_flutter?logo=github\&logoColor=white)](https://github.com/huzaibsayyed/easy_admob_ads_flutter)
[![License](https://img.shields.io/github/license/huzaibsayyed/easy_admob_ads_flutter?logo=open-source-initiative\&logoColor=green)](https://github.com/huzaibsayyed/easy_admob_ads_flutter/blob/main/LICENSE)

A simple, configurable Flutter wrapper for Google AdMob. One EasyAdMobAds.instance sets up the SDK, GDPR/UMP consent, and a global on/off switch for ads. All six ad formats are supported with their own controller or widget.

**Show some ❤️ by giving the [repo](https://github.com/huzaibsayyed/easy_admob_ads_flutter) a ⭐ and liking 👍 the package on [pub.dev](https://pub.dev/packages/easy_admob_ads_flutter)!**

## Screenshots
<p float="left">
  <img src="example/screenshots/demo-iphone.png" width="20%" alt="Static AdMob Demo" />
  <img src="example/screenshots/demo.gif" width="20.1%" alt="Animated AdMob Demo" />
  <img src="example/screenshots/demo-ipad.png" width="31%" alt="Static AdMob Demo" />
</p>

## Features

* Banner (adaptive, optionally collapsible)
* Interstitial
* Rewarded
* Rewarded Interstitial
* App Open (auto-preloaded and shown on app resume)
* Native (small/medium templates)
* GDPR/UMP consent flow, including the "privacy options" re-consent form
* App Tracking Transparency (ATT) consent on iOS 14.5+, requested automatically during `initialize()`
* Network connectivity awareness — ad requests pause while offline and resume as soon as connectivity returns

## Getting started

### 1. Install

```yaml
dependencies:
  easy_admob_ads_flutter: ^<latest_version>
```

### 2. Platform setup

Add your AdMob App ID:

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
  android:name="com.google.android.gms.ads.APPLICATION_ID"
  android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
```

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

### 3. Initialize

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyAdMobAds.instance.initialize(
    config: const EasyAdsConfig(
      androidAdUnitIds: {
        AdType.banner: 'ca-app-pub-.../...',
        AdType.interstitial: 'ca-app-pub-.../...',
      },
      iosAdUnitIds: {
        AdType.banner: 'ca-app-pub-.../...',
        AdType.interstitial: 'ca-app-pub-.../...',
      },
      testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
    ),
  );

  runApp(const MyApp());
}
```

Any `AdType` you don't configure automatically falls back to a Google test ad unit ID
(with a warning logged), so the package works out of the box during development.

## Usage

```dart
// Banner
const EasyBannerAd(collapsible: true, height: 100)

// Native
EasyNativeAd.medium()

// Interstitial
final interstitialAd = EasyInterstitialAd()..loadAd();
await interstitialAd.showAd();

// Rewarded
final rewardedAd = EasyRewardedAd(onRewardEarned: (reward) {
  // grant the reward
})..loadAd();
await rewardedAd.showAd();

// Rewarded Interstitial
final rewardedInterstitialAd = EasyRewardedInterstitialAd(onRewardEarned: (reward) {
  // grant the reward
})..loadAd();
await rewardedInterstitialAd.showAd();

// App Open — preloaded automatically; show it manually if you want:
await EasyAdMobAds.instance.appOpenAd?.showAdIfAvailable();

// Turn all ads on/off (e.g. after a "remove ads" purchase)
EasyAdMobAds.instance.adsEnabled = false;

// GDPR privacy options
if (EasyAdMobAds.instance.isPrivacyOptionsRequired) {
  EasyAdMobAds.instance.showPrivacyOptionsForm();
}
```

See the [`example/`](example/lib/main.dart) app for a full demo screen with all ad types,
the on/off switch, and the consent button wired up.

## Author

##### Huzaib Sayyed

[![GitHub](https://img.shields.io/badge/GitHub-%23121011.svg?logo=github&logoColor=white)](https://github.com/huzaibsayyed) [![LinkedIn](https://custom-icon-badges.demolab.com/badge/LinkedIn-0A66C2?logo=linkedin-white&logoColor=fff)](https://www.linkedin.com/in/huzaif7)

