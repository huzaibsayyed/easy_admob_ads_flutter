import 'package:easy_admob_ads_flutter/easy_admob_ads_flutter.dart';

import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prints package logs to the console during development. Log levels: FINEST < FINER < FINE < CONFIG < INFO < WARNING < SEVERE < SHOUT
  hierarchicalLoggingEnabled = true; // lets individual loggers override root's level
  Logger.root.level = Level.ALL; // default for everything else
  for (final name in [
    'AdConfigDiagnostics',
    'AppLifecycleReactor',
    'EasyAdMobAds',
    'EasyAppOpenAd',
    'EasyBannerAd',
    'EasyInterstitialAd',
    'EasyNativeAd',
    'EasyRewardedAd',
    'EasyRewardedInterstitialAd',
    'EasyConsentManager',
    'EasyAttManager',
  ]) {
    Logger(name).level = Level.WARNING; // verbose only for these
  }
  Logger.root.onRecord.listen((record) => debugPrint('[${record.level.name}] ${record.loggerName}: ${record.message}'));

  // Set your real ad unit IDs here before release. Any type left out falls
  // back to a Google test ad unit ID automatically.
  await EasyAdMobAds.instance.initialize(
    config: const EasyAdsConfig(
      androidAdUnitIds: kTestAdUnitIdsAndroid, // TODO: replace with your Android ad unit IDs
      iosAdUnitIds: kTestAdUnitIdsIOS, // TODO: replace with your iOS ad unit IDs
      testDeviceIds: ['kGADSimulatorID'],
      simulateEeaConsentInDebug: true, // set true to preview the GDPR consent form in debug
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Easy AdMob Ads Demo', home: const AdsDemoScreen());
  }
}

class AdsDemoScreen extends StatefulWidget {
  const AdsDemoScreen({super.key});

  @override
  State<AdsDemoScreen> createState() => _AdsDemoScreenState();
}

class _AdsDemoScreenState extends State<AdsDemoScreen> {
  int _rewardCount = 0;
  late final EasyInterstitialAd _interstitialAd;
  late final EasyRewardedAd _rewardedAd;
  late final EasyRewardedInterstitialAd _rewardedInterstitialAd;

  AdState _interstitialState = AdState.initial;
  AdState _rewardedState = AdState.initial;
  AdState _rewardedInterstitialState = AdState.initial;

  @override
  void initState() {
    super.initState();

    _interstitialAd = EasyInterstitialAd(
      onStateChanged: (state) {
        if (mounted) {
          setState(() => _interstitialState = state);
        }
      },
    )..loadAd();

    _rewardedAd = EasyRewardedAd(
      onStateChanged: (state) {
        setState(() => _rewardedState = state);
      },
      onRewardEarned: (reward) {
        setState(() {
          _rewardCount++;
        });

        _showSnackBar('You earned ${reward.amount} ${reward.type}!');
      },
    )..loadAd();

    _rewardedInterstitialAd = EasyRewardedInterstitialAd(
      onStateChanged: (state) {
        setState(() => _rewardedInterstitialState = state);
      },
      onRewardEarned: (reward) {
        setState(() {
          _rewardCount++;
        });

        _showSnackBar('You earned ${reward.amount} ${reward.type}!');
      },
    )..loadAd();
  }

  @override
  void dispose() {
    _interstitialAd.dispose();
    _rewardedAd.dispose();
    _rewardedInterstitialAd.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showResult(Future<AdResult> Function() show) async {
    final result = await show();
    _showSnackBar(result.message);
  }

  Future<void> _showInterstitialAndNavigate() async {
    final AdResult result = await _interstitialAd.showAd();

    _showSnackBar(result.message);

    if (!mounted) return;

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NextScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final ads = EasyAdMobAds.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Easy AdMob Ads Demo')),
      bottomNavigationBar: const EasyBannerAd(collapsible: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(title: const Text('Ads enabled'), subtitle: const Text('Turn all ads on/off at runtime'), value: ads.adsEnabled, onChanged: (value) => setState(() => ads.adsEnabled = value)),
          const SizedBox(height: 8),
          EasyNativeAd.small(),
          const SizedBox(height: 16),
          _AdButton(label: 'Show Interstitial', state: _interstitialState, onPressed: _showInterstitialAndNavigate),
          _AdButton(label: 'Show Rewarded ($_rewardCount)', state: _rewardedState, onPressed: () => _showResult(_rewardedAd.showAd)),
          _AdButton(label: 'Show Rewarded Interstitial ($_rewardCount)', state: _rewardedInterstitialState, onPressed: () => _showResult(_rewardedInterstitialAd.showAd)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showResult(() => ads.appOpenAd?.showAdIfAvailable() ?? Future.value(const AdResult(wasShown: false, message: 'App Open ad was not preloaded'))),
            child: const Text('Show App Open Ad'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => MobileAds.instance.openAdInspector((error) {
              if (error != null) {
                _showSnackBar('Ad Inspector closed with an error: ${error.message}');
              }
            }),
            child: const Text('Open Ad Inspector'),
          ),
          if (ads.isPrivacyOptionsRequired) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (!ads.isPrivacyOptionsRequired) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No privacy settings are available for your region.')));
                  }
                  return;
                }
                ads.showPrivacyOptionsForm(
                  onDismissed: (error) {
                    if (error != null) {
                      _showSnackBar('${error.errorCode}: ${error.message}');
                    }
                  },
                );
              },
              child: const Text('Privacy Options (GDPR)'),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            "Is FirstTime User: ${ads.isFirstTimeUser ? 'Yes' : 'No'}, Connectivity: ${ads.hasConnectivity ? 'Online' : 'Offline'}",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text('App Tracking Transparency: ${ads.trackingAuthorizationStatus.name}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AdButton extends StatelessWidget {
  final String label;
  final AdState state;
  final VoidCallback onPressed;

  const _AdButton({required this.label, required this.state, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 8),
            Text('(${state.name})', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class NextScreen extends StatelessWidget {
  const NextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Next Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64),
            const SizedBox(height: 16),
            Text('Welcome to the Next Screen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('The interstitial ad was completed or was not available.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }
}
