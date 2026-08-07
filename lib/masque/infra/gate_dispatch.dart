import 'dart:convert';

import '../config/masque_config.dart';
import '../core/stage_models.dart';
import 'masked_agent.dart';
import 'stage_vault.dart';
import 'troupe_tracker.dart';

/// POSTs the flat attribution body to the config endpoint and parses the
/// verdict. The partner app identity travels as X-Partner-App-* request
/// headers (not an app-id / app-name User-Agent suffix — see MaskedAgent).
class GateDispatch {
  GateDispatch(this._agent, this._vault);

  final MaskedAgent _agent;
  final StageVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!MasqueConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      masqueTrace(() => '[VJS.GATE] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(MasqueConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Partner-App-Id': MasqueConfig.bundleId,
              'X-Partner-App-Name': MasqueConfig.appNameToken,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 19));
      masqueTrace(
        () => '[VJS.GATE] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');
      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      masqueTrace(() => '[VJS.GATE] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
