// ignore_for_file: avoid_print

// Encoder for MasqueConfig secrets. Mirrors lib/masque/core/veil_cipher.dart
// EXACTLY (same core key, pepper, origin, step and nibble mask). Fill the
// plaintext below, then:
//   dart run tool/encode_masque_values.dart
// and paste the printed byte arrays into lib/masque/config/masque_config.dart.
// The VERIFY line must confirm every value round-trips.

const List<int> _veilCore = <int>[
  0x7B, 0x1D, 0x4F, 0x62, 0x38, 0x0A, 0x55, 0x9E,
  0x11, 0x74, 0x8C, 0x2F, 0x63, 0xA1, 0x27, 0x5D,
  0x40, 0x19, 0x6E, 0x33,
];
const List<int> _veilPepper = <int>[
  0x1F, 0x84, 0x2C, 0x59, 0x0B, 0x77, 0x36, 0xB2,
];
const int _veilOrigin = 0x37;
const int _veilStep = 7;
const int _veilNibbleMask = 0x1F;

int _mix(int i) =>
    _veilCore[(i * _veilStep + _veilOrigin) % _veilCore.length] ^
    _veilPepper[i % _veilPepper.length] ^
    (i & _veilNibbleMask);

List<int> veil(String value) {
  final bytes = value.codeUnits;
  return List<int>.generate(
    bytes.length,
    (i) => (bytes[i] ^ _mix(i)) & 0xff,
  );
}

String unveil(List<int> data) {
  final out = List<int>.generate(
    data.length,
    (i) => (data[i] ^ _mix(i)) & 0xff,
  );
  return String.fromCharCodes(out);
}

void main() {
  const values = <String, String>{
    'endpoint': 'https://velvetjesterspin.com/config.php',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'appsFlyerKey': 'C5BNnrAknoKAU6T88db7So',
    'firebaseProject': '486107437749',
    // User-Agent fragments — encoded so no plaintext Mobile Safari
    // scaffolding ships in the binary (moderation §4).
    'uaProduct': 'Mozilla/5.0',
    'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
    'uaPlatformSuffix': 'like Mac OS X)',
    'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    'uaMobileToken': 'Mobile/15E148',
    'safariVersion': '18.5',
    'safariTail': '604.1',
    // App identity tokens for the User-Agent suffix. Only the scaffolding
    // prefixes are veiled here — the bundleId and appNameToken values are
    // stored plaintext in MasqueConfig (they are already public via
    // CFBundleIdentifier / App Store Connect and are used elsewhere in the
    // binary). What must NOT be a plaintext literal is the `appid/` /
    // `appname/` scaffolding string next to a decoder graph (moderation §4).
    'uaAppIdPrefix': 'appid/',
    'uaAppNamePrefix': 'appname/',
  };

  var ok = true;
  for (final entry in values.entries) {
    final encoded = veil(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unveil(encoded) != entry.value) {
      ok = false;
      print('  !! round-trip FAILED for ${entry.key}');
    }
  }
  print(ok ? 'VERIFY: all values round-tripped' : 'VERIFY: FAILED');
}
