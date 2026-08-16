import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity + reachability checks for the masque pipeline.
class ReachScout {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInterface() async {
    try {
      final status = await _connectivity.checkConnectivity();
      return status.any((value) => value != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Probes well-known third-party hosts (not our own domain) so a VPN or
  /// a not-yet-propagated app domain never yields a false "offline". Each
  /// lookup is time-boxed at ~2.4 s so the retry button can never hang.
  /// The list is rotated per project — every sibling probing the same two
  /// hosts is one more cluster edge (moderation §1).
  static const List<String> _reachHosts = <String>[
    'www.gstatic.com',
    'mzstatic.com',
    'one.one.one.one',
  ];

  Future<bool> canReachNetwork() async {
    if (!await hasInterface()) return false;
    for (final host in _reachHosts) {
      try {
        final records = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(milliseconds: 2400));
        if (records.any((record) => record.rawAddress.isNotEmpty)) {
          return true;
        }
      } catch (_) {
        // Try the next host before declaring offline.
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;
}
