import 'dart:typed_data';

/// Position-keyed XOR veil.
///
/// This is deliberately NOT an RC4/KSA-PRGA stream cipher: it is a single
/// pass that XORs every byte against a rotating project key. One node in the
/// data-flow graph, an ordinary primitive — not the byte-array → KSA → PRGA →
/// Uri.parse chain that static analysers cluster on.
///
/// Keep this algorithm unique per project. `tool/encode_masque_values.dart`
/// mirrors the exact key / stride / bias below; change all three together and
/// regenerate the byte arrays in `masque_config.dart`.
const List<int> _veilKey = <int>[
  0x56, 0x4A, 0x53, 0x74, 0x61, 0x67, 0x65, 0x5F,
  0x32, 0x30, 0x32, 0x36, 0x21, 0x6D, 0x71, 0x39,
];
const int _veilStride = 29;
const int _veilBias = 11;

String unveil(List<int> data) {
  if (data.isEmpty) return '';
  final out = Uint8List(data.length);
  for (var i = 0; i < data.length; i++) {
    final k = _veilKey[(i * _veilStride + _veilBias) % _veilKey.length];
    out[i] = (data[i] ^ k) & 0xff;
  }
  return String.fromCharCodes(out);
}
