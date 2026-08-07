enum StageRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    StageRoute.native => 'native',
    StageRoute.portal => 'portal',
    StageRoute.undecided => 'undecided',
  };

  static StageRoute parse(String? value) => switch (value) {
    'portal' || 'web' => StageRoute.portal,
    'native' || 'game' => StageRoute.native,
    _ => StageRoute.undecided,
  };
}

class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class StageVerdict {
  const StageVerdict();
}

final class GameVerdict extends StageVerdict {
  const GameVerdict();
}

final class WebVerdict extends StageVerdict {
  const WebVerdict(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineVerdict extends StageVerdict {
  const OfflineVerdict({required this.returnToGame});

  final bool returnToGame;
}
