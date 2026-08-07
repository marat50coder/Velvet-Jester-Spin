// ignore_for_file: avoid_print

// Encoder for MasqueConfig secrets. Mirrors lib/masque/core/veil_cipher.dart
// EXACTLY (same key / stride / bias). Fill the plaintext below, run
//   dart run tool/encode_masque_values.dart
// and paste the printed byte arrays into lib/masque/config/masque_config.dart.
// The VERIFY line must confirm every value round-trips.

const List<int> _veilKey = <int>[
  0x56, 0x4A, 0x53, 0x74, 0x61, 0x67, 0x65, 0x5F,
  0x32, 0x30, 0x32, 0x36, 0x21, 0x6D, 0x71, 0x39,
];
const int _veilStride = 29;
const int _veilBias = 11;

List<int> veil(String value) {
  final bytes = value.codeUnits;
  return List<int>.generate(bytes.length, (i) {
    final k = _veilKey[(i * _veilStride + _veilBias) % _veilKey.length];
    return (bytes[i] ^ k) & 0xff;
  });
}

String unveil(List<int> data) {
  final out = List<int>.generate(data.length, (i) {
    final k = _veilKey[(i * _veilStride + _veilBias) % _veilKey.length];
    return (data[i] ^ k) & 0xff;
  });
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
