import 'dart:convert';

import 'package:crypto/crypto.dart';

class BackupPayloadEncoding {
  const BackupPayloadEncoding({
    required this.payload,
    required this.checksum,
    required this.json,
  });

  final Map<String, dynamic> payload;
  final String checksum;
  final String json;
}

class BackupPayloadCodec {
  const BackupPayloadCodec();

  BackupPayloadEncoding encode(Map<String, dynamic> payload) {
    final checksum = calculateChecksum(payload);
    final fullPayload = <String, dynamic>{...payload, 'checksum': checksum};
    return BackupPayloadEncoding(
      payload: fullPayload,
      checksum: checksum,
      json: jsonEncode(fullPayload),
    );
  }

  Map<String, dynamic> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Backup JSON root must be an object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String calculateChecksum(Map<String, dynamic> payload) {
    final sanitized = Map<String, dynamic>.from(payload);
    sanitized.remove('checksum');
    final canonical = jsonEncode(sanitized);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  bool verifyChecksum(Map<String, dynamic> payload) {
    final checksum = payload['checksum']?.toString() ?? '';
    if (checksum.isEmpty) return false;
    return calculateChecksum(payload) == checksum;
  }
}
