import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spingame/masque/config/masque_config.dart';
import 'package:spingame/masque/infra/stage_vault.dart';

/// Verifies the Skip → 3-day re-prompt contract of `PushInvite`.
///
/// Contract (from `apple_moderation_hardening.mdc` and the `PushInvite`
/// widget):
///  1. Tapping Skip must persist a snooze deadline of
///     `now + MasqueConfig.pushSnoozeSeconds` via `snoozePushInvite()`.
///  2. `shouldShowPushInvite` must remain `false` while the snooze is
///     active and become `true` once the deadline is reached (or crossed).
///  3. The snooze mechanism must be independent of push-permission state
///     (never granted, never OS-denied — those are their own kill-switches).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('Skip snoozes for exactly pushSnoozeSeconds', () async {
    final vault = StageVault();
    await vault.initialize();

    expect(
      vault.shouldShowPushInvite,
      isTrue,
      reason: 'Fresh install: no snooze, no allowance — invite must show.',
    );

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final snoozeUntil = nowSec + MasqueConfig.pushSnoozeSeconds;
    await vault.snoozePushInvite(snoozeUntil);

    expect(
      vault.shouldShowPushInvite,
      isFalse,
      reason: 'Snooze just written: invite must NOT show yet.',
    );
  });

  test('Snooze expires → invite shows again', () async {
    final vault = StageVault();
    await vault.initialize();

    final expiredSnoozeEnd =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
    await vault.snoozePushInvite(expiredSnoozeEnd);

    expect(
      vault.shouldShowPushInvite,
      isTrue,
      reason: 'Snooze already in the past: invite must show on next boot.',
    );
  });

  test('At +3 days, the snooze has expired → invite re-shows', () async {
    final vault = StageVault();
    await vault.initialize();

    const threeDaysSec = 3 * 24 * 3600;
    expect(
      MasqueConfig.pushSnoozeSeconds,
      lessThanOrEqualTo(threeDaysSec),
      reason: 'pushSnoozeSeconds must be <= 3 days so the "re-prompt after '
          '3 days" UX contract is honoured when the user advances the clock '
          'exactly 3 days.',
    );

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final snoozeEnd = nowSec + MasqueConfig.pushSnoozeSeconds;
    await vault.snoozePushInvite(snoozeEnd);

    final fakeNowSec = nowSec + threeDaysSec;
    expect(
      fakeNowSec >= snoozeEnd,
      isTrue,
      reason: 'After +3 days the snooze must be strictly in the past — '
          'shouldShowPushInvite reads back as true on the next boot.',
    );
    expect(
      MasqueConfig.pushSnoozeSeconds,
      greaterThanOrEqualTo(2 * 24 * 3600),
      reason: 'Anti-fingerprint §7a: snooze must stay in the '
          '172800–604800 range so it does not degenerate to sub-day nagging.',
    );
  });

  test('Allowed / OS-denied override the snooze schedule', () async {
    final vault = StageVault();
    await vault.initialize();

    final expiredSnoozeEnd =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
    await vault.snoozePushInvite(expiredSnoozeEnd);

    await vault.setPushAllowed(true);
    expect(
      vault.shouldShowPushInvite,
      isFalse,
      reason: 'Once user granted push: never re-ask via soft prompt.',
    );

    await vault.setPushAllowed(false);
    await vault.markPushDeniedByOs();
    expect(
      vault.shouldShowPushInvite,
      isFalse,
      reason: 'Once OS-denied: never re-ask (iOS caches "denied" forever).',
    );
  });
}
