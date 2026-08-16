import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/audio.dart';
import 'core/storage.dart';
import 'masque/config/masque_config.dart';
import 'masque/infra/gate_dispatch.dart';
import 'masque/infra/masked_agent.dart';
import 'masque/infra/pulse_relay.dart';
import 'masque/infra/reach_scout.dart';
import 'masque/infra/stage_vault.dart';
import 'masque/infra/troupe_tracker.dart';
import 'masque/stage_director.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Boot supports both orientations (the boot splash + gray screens rotate);
  // the white game locks landscape once its menu appears.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // White-game services (needed on the organic path).
  final prefs = await SharedPreferences.getInstance();
  await AudioManager.instance.init();

  // Gray-layer services.
  final vault = StageVault();
  final agent = MaskedAgent();
  await Future.wait<void>(<Future<void>>[vault.initialize(), agent.prepare()]);

  var productionServicesReady = false;
  if (MasqueConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
    } catch (error) {
      assert(() {
        debugPrint('[SPIN.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        // App Check must never block FCM / gray routing.
        assert(() {
          debugPrint('[SPIN.BOOT] AppCheck skipped: $error');
          return true;
        }());
      }
    }
  }

  final scout = ReachScout();
  final pulse = PulseRelay(vault, enabled: productionServicesReady);
  // Kick pulse.boot() early (fire-and-forget) so onMessageOpenedApp is
  // registered BEFORE any background/foreground tap can fire. Awaiting
  // would delay first frame; the pipeline will `await pulse.boot()` again
  // at the correct moment — the future is idempotent (see PulseRelay).
  unawaited(pulse.boot());
  final tracker = TroupeTracker(agent);
  final director = StageDirector(
    vault: vault,
    scout: scout,
    tracker: tracker,
    dispatch: GateDispatch(agent, vault),
    pulse: pulse,
    agent: agent,
    runtimeEnabled: MasqueConfig.grayCredentialsReady,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProgress(prefs),
      child: VelvetJesterApp(director: director),
    ),
  );
}
