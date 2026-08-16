import 'package:flutter_test/flutter_test.dart';
import 'package:spingame/masque/config/masque_config.dart';

void main() {
  test('MasqueConfig veiled secrets round-trip', () {
    expect(
      MasqueConfig.endpoint,
      'https://velvetjesterspin.com/config.php',
    );
    expect(
      MasqueConfig.gcdBase,
      'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    );
    expect(MasqueConfig.appsFlyerKey, 'C5BNnrAknoKAU6T88db7So');
    expect(MasqueConfig.firebaseProjectNumber, '486107437749');
    expect(MasqueConfig.uaProduct, 'Mozilla/5.0');
    expect(MasqueConfig.uaPlatformPrefix, '(iPhone; CPU iPhone OS');
    expect(MasqueConfig.uaPlatformSuffix, 'like Mac OS X)');
    expect(
      MasqueConfig.uaEngine,
      'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    );
    expect(MasqueConfig.uaMobileToken, 'Mobile/15E148');
    expect(MasqueConfig.safariVersion, '18.5');
    expect(MasqueConfig.safariTail, '604.1');
    expect(MasqueConfig.uaAppIdPrefix, 'appid/');
    expect(MasqueConfig.uaAppNamePrefix, 'appname/');
  });
}
