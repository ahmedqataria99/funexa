import 'package:sqlite3/sqlite3.dart';

const paths = <String>[
  r'C:\Users\ahmed\AppData\Local\Furnexa\furnexa.db',
  r'D:\avatar\vs code\My APPS\furnexa\build\windows\x64\runner\Release\.dart_tool\sqflite_common_ffi\databases\furnexa.db',
  r'D:\avatar\vs code\My APPS\furnexa\.dart_tool\sqflite_common_ffi\databases\furnexa.db',
];

void main() {
  for (final path in paths) {
    print('\n=== DATABASE $path ===');
    try {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        print(
          '[VERSION] ${db.select('PRAGMA user_version').first['user_version']}',
        );
        print(
          '[DATABASE LIST] ${db.select('PRAGMA database_list').map((row) => row.values.toList()).toList()}',
        );
        for (final table in [
          'factories',
          'warehouses',
          'raw_materials',
          'products',
          'stock_balances',
          'stock_transactions',
          'purchase_requests',
          'purchase_request_items',
          'users',
          'roles',
          'user_scopes',
          'audit_logs',
        ]) {
          final exists = db.select(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
            [table],
          );
          if (exists.isEmpty) {
            print('[SCHEMA] $table=MISSING');
          } else {
            final count = db
                .select('SELECT COUNT(*) AS n FROM "$table"')
                .first['n'];
            print('[TABLE] $table rows=$count schema=${exists.first['sql']}');
          }
        }

        final warehouses = db.select(
          'SELECT id, factoryId, name, code, state, createdAt FROM warehouses ORDER BY createdAt DESC',
        );
        for (final row in warehouses) {
          print('[WAREHOUSE] ${row.values.toList()}');
        }

        final balances = db.select('''
          SELECT b.id, b.warehouseId, w.factoryId, w.state AS warehouseState,
                 b.itemId, b.itemType, b.quantity, b.updatedAt,
                 r.name AS rawName, r.code AS rawCode, r.active AS rawActive,
                 p.name AS productName, p.code AS productCode, p.active AS productActive
          FROM stock_balances b
          LEFT JOIN warehouses w ON w.id = b.warehouseId
          LEFT JOIN raw_materials r ON b.itemType = 'RAW_MATERIAL' AND r.id = b.itemId
          LEFT JOIN products p ON b.itemType = 'PRODUCT' AND p.id = b.itemId
          ORDER BY b.updatedAt DESC
        ''');
        for (final row in balances) {
          print('[BALANCE] ${row.values.toList()}');
        }
        final allStockRows = db.select('''
          SELECT itemId, itemType, SUM(quantity) AS quantity
          FROM stock_balances WHERE quantity > 0
          GROUP BY itemId, itemType ORDER BY itemId ASC
        ''');
        print(
          '[STOCK EXACT ALL SQL] count=${allStockRows.length} rows=${allStockRows.map((row) => row.values.toList()).toList()}',
        );
        for (final warehouse in warehouses) {
          final rows = db.select(
            '''
            SELECT id, warehouseId, itemId, itemType, quantity, createdAt, updatedAt
            FROM stock_balances WHERE warehouseId = ? AND quantity > 0
            ORDER BY updatedAt DESC
          ''',
            [warehouse['id']],
          );
          print(
            '[STOCK EXACT WAREHOUSE SQL] warehouse=${warehouse['id']} count=${rows.length} rows=${rows.map((row) => row.values.toList()).toList()}',
          );
        }
        final requests = db.select(
          'SELECT id, requestNumber, requestDate, requestedBy, status, createdAt, updatedAt FROM purchase_requests ORDER BY requestDate DESC',
        );
        for (final request in requests) {
          print('[REQUEST] ${request.values.toList()}');
          final items = db.select(
            'SELECT id, purchaseRequestId, itemId, itemType, quantity, unitId FROM purchase_request_items WHERE purchaseRequestId = ?',
            [request['id']],
          );
          print(
            '[REQUEST ITEMS] request=${request['id']} count=${items.length} rows=${items.map((row) => row.values.toList()).toList()}',
          );
        }
        final users = db.select('''
          SELECT u.id, u.username, u.displayName, u.roleId, u.active,
                 r.name AS roleName, r.isSystemRole, r.active AS roleActive
          FROM users u LEFT JOIN roles r ON r.id = u.roleId ORDER BY u.createdAt
        ''');
        for (final user in users) {
          print('[USER] ${user.values.toList()}');
          final scopes = db.select(
            'SELECT id, userId, scopeType, scopeId FROM user_scopes WHERE userId = ?',
            [user['id']],
          );
          print(
            '[USER SCOPES] user=${user['id']} count=${scopes.length} rows=${scopes.map((row) => row.values.toList()).toList()}',
          );
          final permissions = db.select(
            '''
            SELECT p.code FROM permissions p
            JOIN role_permissions rp ON rp.permissionId = p.id
            WHERE rp.roleId = ? ORDER BY p.code
          ''',
            [user['roleId']],
          );
          print(
            '[ROLE PERMISSIONS] role=${user['roleId']} count=${permissions.length} codes=${permissions.map((row) => row['code']).toList()}',
          );
        }
        final audits = db.select('''
          SELECT id, userId, action, module, entityType, entityId, timestamp
          FROM audit_logs ORDER BY timestamp DESC LIMIT 20
        ''');
        for (final audit in audits) {
          print('[AUDIT] ${audit.values.toList()}');
        }
      } finally {
        db.dispose();
      }
    } catch (error) {
      print('[OPEN ERROR] $error');
    }
  }
}
