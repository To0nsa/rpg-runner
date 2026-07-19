import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Requests canonical settlement after a validator has durably handed off an
/// accepted run. Implementations must not derive rewards or write Firestore.
abstract interface class SettlementDispatcher {
  Future<SettlementDispatchOutcome> dispatch({required String runSessionId});
}

enum SettlementDispatchOutcome { settled, alreadySettled, disabled }

/// Keeps validator behavior usable without an immediate-dispatch endpoint.
///
/// Eventarc and scheduled repair still settle the durable handoff in this mode.
class NoopSettlementDispatcher implements SettlementDispatcher {
  const NoopSettlementDispatcher();

  @override
  Future<SettlementDispatchOutcome> dispatch({
    required String runSessionId,
  }) async => SettlementDispatchOutcome.disabled;
}

/// Obtains an OIDC token for an IAM-protected internal HTTP endpoint.
abstract interface class IdentityTokenProvider {
  Future<String> tokenForAudience(Uri audience);
}

/// Reads an identity token from the Cloud Run metadata server.
///
/// This works only in a Google-managed runtime with a service identity. Tests
/// inject [IdentityTokenProvider] instead of reaching the metadata server.
class MetadataIdentityTokenProvider implements IdentityTokenProvider {
  MetadataIdentityTokenProvider({http.Client? client, Uri? metadataIdentityUri})
    : _client = client ?? http.Client(),
      _metadataIdentityUri =
          metadataIdentityUri ??
          Uri.parse(
            'http://metadata.google.internal/computeMetadata/v1/instance/'
            'service-accounts/default/identity',
          );

  final http.Client _client;
  final Uri _metadataIdentityUri;

  @override
  Future<String> tokenForAudience(Uri audience) async {
    final response = await _client.get(
      _metadataIdentityUri.replace(
        queryParameters: <String, String>{
          'audience': audience.toString(),
          'format': 'full',
        },
      ),
      headers: const <String, String>{'Metadata-Flavor': 'Google'},
    );
    final token = response.body.trim();
    if (response.statusCode != 200 || token.isEmpty) {
      throw StateError(
        'Cloud Run metadata identity token request failed with '
        'HTTP ${response.statusCode}.',
      );
    }
    return token;
  }
}

/// Calls the Functions-owned settlement endpoint with the validator identity.
///
/// A non-success response or timeout throws so the worker can record fallback
/// delivery and let Eventarc/repair settle the already-durable handoff.
class FunctionsSettlementDispatcher implements SettlementDispatcher {
  FunctionsSettlementDispatcher({
    required Uri endpoint,
    required IdentityTokenProvider identityTokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
  }) : _endpoint = _validateEndpoint(endpoint),
       _identityTokenProvider = identityTokenProvider,
       _client = client ?? http.Client();

  final Uri _endpoint;
  final IdentityTokenProvider _identityTokenProvider;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<SettlementDispatchOutcome> dispatch({required String runSessionId}) {
    final normalizedRunSessionId = runSessionId.trim();
    if (normalizedRunSessionId.isEmpty) {
      throw ArgumentError.value(
        runSessionId,
        'runSessionId',
        'must be non-empty.',
      );
    }
    return _dispatch(normalizedRunSessionId).timeout(timeout);
  }

  Future<SettlementDispatchOutcome> _dispatch(String runSessionId) async {
    final identityToken = await _identityTokenProvider.tokenForAudience(
      _endpoint,
    );
    final response = await _client.post(
      _endpoint,
      headers: <String, String>{
        'Authorization': 'Bearer $identityToken',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(<String, String>{'runSessionId': runSessionId}),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Immediate settlement request for "$runSessionId" failed with '
        'HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Immediate settlement response is not JSON.');
    }
    return switch (decoded['outcome']) {
      'settled' => SettlementDispatchOutcome.settled,
      'already_settled' => SettlementDispatchOutcome.alreadySettled,
      _ => throw const FormatException(
        'Immediate settlement response has an invalid outcome.',
      ),
    };
  }

  static Uri _validateEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'must be an absolute HTTPS URL.',
      );
    }
    return endpoint;
  }
}
