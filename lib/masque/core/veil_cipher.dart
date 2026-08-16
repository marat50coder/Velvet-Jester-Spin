import 'dart:typed_data';

/// Layered XOR veil (position + pepper + rolling nibble).
///
/// Kept intentionally NOT an RC4 / KSA-PRGA stream cipher: it is a linear
/// single pass. Compared to the earlier position-only XOR, each output byte
/// is folded against two independent key material lists AND a rolling
/// position nibble, so the data-flow graph is a wider fan-in than the naive
/// `byte ^ key[i % n]` shape that clusters trivially.
///
/// This algorithm MUST stay unique to this project; the encoder in
/// `tool/encode_masque_values.dart` mirrors every constant below, and if any
/// of them shifts the byte arrays in `masque_config.dart` need to be
/// regenerated in the same sweep.
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

String unveil(List<int> data) {
  if (data.isEmpty) return '';
  final out = Uint8List(data.length);
  for (var i = 0; i < data.length; i++) {
    final core = _veilCore[(i * _veilStep + _veilOrigin) % _veilCore.length];
    final pepper = _veilPepper[i % _veilPepper.length];
    final nibble = i & _veilNibbleMask;
    out[i] = (data[i] ^ core ^ pepper ^ nibble) & 0xff;
  }
  return String.fromCharCodes(out);
}
