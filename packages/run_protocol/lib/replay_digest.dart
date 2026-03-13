import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'codecs/canonical_json_codec.dart';

final class ReplayDigest {
  static final RegExp _sha256Hex = RegExp(r'^[a-f0-9]{64}$');

  static String canonicalSha256ForMap(Map<String, Object?> canonicalPayload) {
    final canonicalJson = canonicalJsonEncode(canonicalPayload);
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  static bool isValidSha256Hex(String value) => _sha256Hex.hasMatch(value);
}
