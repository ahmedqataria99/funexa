import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/features/backup_restore/data/backup_payload_codec.dart';

void main() {
  const codec = BackupPayloadCodec();

  test('encode preserves payload fields and adds a sha256 checksum', () {
    final payload = <String, dynamic>{
      'backupId': 'backup-1',
      'databaseVersion': 41,
      'backupFormatVersion': 1,
      'database': {
        'tables': <Map<String, dynamic>>[
          {
            'table': 'factories',
            'rows': <Map<String, dynamic>>[
              {'id': 'factory-1', 'name': 'Factory Alpha'},
            ],
          },
        ],
      },
    };

    final encoding = codec.encode(payload);

    expect(encoding.payload['backupId'], 'backup-1');
    expect(encoding.payload['checksum'], encoding.checksum);
    expect(encoding.checksum, hasLength(64));
    expect(codec.verifyChecksum(encoding.payload), isTrue);
  });

  test('checksum uses canonical json content excluding checksum', () {
    final payload = <String, dynamic>{
      'backupId': 'backup-1',
      'databaseVersion': 41,
      'database': {'tables': const <dynamic>[]},
    };

    final first = codec.encode(payload);
    final copy = Map<String, dynamic>.from(first.payload);

    expect(codec.verifyChecksum(copy), isTrue);
    copy['checksum'] = '${codec.calculateChecksum(copy)}-tampered';
    expect(codec.verifyChecksum(copy), isFalse);
  });

  test('decode round-trips encoded JSON and table rows', () {
    final payload = <String, dynamic>{
      'backupId': 'backup-2',
      'recordCount': 1,
      'database': {
        'tables': <Map<String, dynamic>>[
          {
            'table': 'stock_balances',
            'rows': <Map<String, dynamic>>[
              {'id': 'stock-1', 'quantity': 20},
            ],
          },
        ],
      },
    };

    final encoding = codec.encode(payload);
    final decoded = codec.decode(encoding.json);

    expect(decoded['backupId'], 'backup-2');
    expect(decoded['recordCount'], 1);
    expect(codec.verifyChecksum(decoded), isTrue);
    expect(decoded['database']['tables'].first['table'], 'stock_balances');
  });

  test('decode rejects a non-object JSON root', () {
    expect(() => codec.decode('[1,2,3]'), throwsA(isA<FormatException>()));
  });

  test('decode rejects malformed JSON', () {
    expect(() => codec.decode('{not-json'), throwsA(isA<FormatException>()));
  });
}
