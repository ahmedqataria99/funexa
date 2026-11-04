import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late Database legacyDatabase;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDirectory = await Directory.systemTemp.createTemp(
      'furnexa-po-status-migration-',
    );
    legacyDatabase = await databaseFactoryFfi.openDatabase(
      '${tempDirectory.path}${Platform.pathSeparator}legacy.db',
    );
    await _createLegacySchema(legacyDatabase);
  });

  tearDown(() async {
    await legacyDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'version 30 rebuild preserves orders, lines, receipts and returns',
    () async {
      final db = legacyDatabase;
      final before = <String, int>{
        for (final table in [
          'purchase_orders',
          'purchase_order_items',
          'purchase_receipts',
          'purchase_receipt_items',
          'purchase_returns',
          'purchase_return_items',
        ])
          table:
              (await db.rawQuery(
                    'SELECT COUNT(*) AS count FROM "$table"',
                  )).single['count']!
                  as int,
      };
      expect(
        (await db.rawQuery('PRAGMA user_version')).single['user_version'],
        29,
      );
      expect(before['purchase_orders'], 3);
      expect(before['purchase_order_items'], 2);

      await FurnexaDatabase.instance.migrate(db, 29, 30);

      expect(
        (await db.rawQuery('PRAGMA user_version')).single['user_version'],
        30,
      );
      expect(AppConstants.databaseVersion, 30);
      for (final entry in before.entries) {
        expect(
          (await db.rawQuery(
            'SELECT COUNT(*) AS count FROM "${entry.key}"',
          )).single['count'],
          entry.value,
          reason: '${entry.key} row count must be preserved',
        );
      }

      final migratedOrders = await db.query(
        'purchase_orders',
        orderBy: 'id ASC',
      );
      expect(migratedOrders.map((row) => row['status']), [
        'APPROVED',
        'DRAFT',
        'FULLY_RECEIVED',
      ]);
      final approved = migratedOrders.first;
      expect(approved['id'], 'legacy-approved-order');
      expect(approved['supplierId'], 'legacy-supplier');
      expect(approved['purchaseRequestId'], 'legacy-request');
      expect(approved['orderNumber'], 'PO-LEGACY-APPROVED');
      expect(approved['subtotal'], 3300);
      expect(approved['discount'], 15);
      expect(approved['tax'], 25);
      expect(approved['grandTotal'], 3310);
      expect(approved['notes'], 'preserve order note');
      expect(approved['orderDate'], 1000);
      expect(approved['createdAt'], 1100);
      expect(approved['updatedAt'], 1200);

      final lines = await db.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: ['legacy-approved-order'],
        orderBy: 'id ASC',
      );
      expect(lines, hasLength(2));
      expect(lines[0]['unitPrice'], 27.5);
      expect(lines[0]['quantity'], 100);
      expect(lines[0]['discount'], 10);
      expect(lines[0]['tax'], 20);
      expect(lines[0]['lineTotal'], 2760);
      expect(lines[0]['receivedQuantity'], 80);
      expect(lines[0]['notes'], 'preserve line one');
      expect(lines[1]['unitPrice'], 18);
      expect(lines[1]['quantity'], 30);
      expect(lines[1]['receivedQuantity'], 0);

      final receipt = (await db.query('purchase_receipts')).single;
      expect(receipt['purchaseOrderId'], 'legacy-approved-order');
      expect(receipt['receivedBy'], 'legacy-user');
      final receiptLine = (await db.query('purchase_receipt_items')).single;
      expect(receiptLine['purchaseOrderItemId'], 'legacy-order-line-one');
      expect(receiptLine['receivedQuantity'], 80);
      final purchaseReturn = (await db.query('purchase_returns')).single;
      expect(purchaseReturn['purchaseOrderId'], 'legacy-approved-order');
      expect(purchaseReturn['supplierId'], 'legacy-supplier');
      expect(
        (await db.query('purchase_return_items')).single['unitPrice'],
        27.5,
      );

      final orderIndexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN (?, ?, ?, ?)",
        [
          'idx_purchase_orders_supplier',
          'idx_purchase_receipts_order',
          'idx_purchase_returns_supplier',
          'idx_purchase_return_items_return',
        ],
      );
      expect(orderIndexes, hasLength(4));
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      await db.update(
        'purchase_orders',
        {'status': 'APPROVED'},
        where: 'id = ?',
        whereArgs: ['legacy-draft-order'],
      );
      expect(
        (await db.query(
          'purchase_orders',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: ['legacy-draft-order'],
        )).single['status'],
        'APPROVED',
      );
      await expectLater(
        db.update(
          'purchase_orders',
          {'status': 'CONFIRMED'},
          where: 'id = ?',
          whereArgs: ['legacy-draft-order'],
        ),
        throwsException,
      );
    },
  );
}

Future<void> _createLegacySchema(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
  await db.execute('CREATE TABLE suppliers (id TEXT PRIMARY KEY)');
  await db.execute('CREATE TABLE purchase_requests (id TEXT PRIMARY KEY)');
  await db.execute('CREATE TABLE warehouses (id TEXT PRIMARY KEY)');
  await db.execute('CREATE TABLE units (id TEXT PRIMARY KEY)');
  await db.execute('''
    CREATE TABLE purchase_orders (
      id TEXT PRIMARY KEY,
      orderNumber TEXT NOT NULL UNIQUE,
      supplierId TEXT NOT NULL,
      purchaseRequestId TEXT,
      orderDate INTEGER NOT NULL,
      expectedDeliveryDate INTEGER,
      status TEXT NOT NULL CHECK(status IN ('DRAFT','CONFIRMED','PARTIALLY_RECEIVED','FULLY_RECEIVED','CANCELLED')),
      subtotal REAL NOT NULL DEFAULT 0,
      discount REAL NOT NULL DEFAULT 0,
      tax REAL NOT NULL DEFAULT 0,
      grandTotal REAL NOT NULL DEFAULT 0,
      notes TEXT,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT,
      FOREIGN KEY (purchaseRequestId) REFERENCES purchase_requests(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE purchase_order_items (
      id TEXT PRIMARY KEY,
      purchaseOrderId TEXT NOT NULL,
      itemId TEXT NOT NULL,
      itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL','PRODUCT')),
      quantity REAL NOT NULL CHECK(quantity > 0),
      unitId TEXT NOT NULL,
      unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
      discount REAL NOT NULL DEFAULT 0,
      tax REAL NOT NULL DEFAULT 0,
      lineTotal REAL NOT NULL DEFAULT 0,
      receivedQuantity REAL NOT NULL DEFAULT 0 CHECK(receivedQuantity >= 0),
      notes TEXT,
      UNIQUE(purchaseOrderId, itemId, itemType),
      FOREIGN KEY (purchaseOrderId) REFERENCES purchase_orders(id) ON DELETE RESTRICT,
      FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE purchase_receipts (
      id TEXT PRIMARY KEY,
      receiptNumber TEXT NOT NULL UNIQUE,
      purchaseOrderId TEXT NOT NULL,
      warehouseId TEXT NOT NULL,
      receiptDate INTEGER NOT NULL,
      notes TEXT,
      createdAt INTEGER NOT NULL,
      receivedBy TEXT,
      FOREIGN KEY (purchaseOrderId) REFERENCES purchase_orders(id) ON DELETE RESTRICT,
      FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE purchase_receipt_items (
      id TEXT PRIMARY KEY,
      purchaseReceiptId TEXT NOT NULL,
      purchaseOrderItemId TEXT NOT NULL,
      receivedQuantity REAL NOT NULL CHECK(receivedQuantity > 0),
      unitId TEXT NOT NULL,
      notes TEXT,
      FOREIGN KEY (purchaseReceiptId) REFERENCES purchase_receipts(id) ON DELETE RESTRICT,
      FOREIGN KEY (purchaseOrderItemId) REFERENCES purchase_order_items(id) ON DELETE RESTRICT,
      FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE purchase_returns (
      id TEXT PRIMARY KEY,
      returnNumber TEXT NOT NULL UNIQUE,
      purchaseOrderId TEXT NOT NULL,
      purchaseReceiptId TEXT,
      supplierId TEXT NOT NULL,
      warehouseId TEXT NOT NULL,
      returnDate INTEGER NOT NULL,
      reason TEXT,
      status TEXT NOT NULL CHECK(status IN ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED')) DEFAULT 'PENDING',
      notes TEXT,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      FOREIGN KEY (purchaseOrderId) REFERENCES purchase_orders(id) ON DELETE RESTRICT,
      FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT,
      FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('''
    CREATE TABLE purchase_return_items (
      id TEXT PRIMARY KEY,
      purchaseReturnId TEXT NOT NULL,
      itemId TEXT NOT NULL,
      itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
      quantity REAL NOT NULL CHECK(quantity >= 0),
      unitId TEXT NOT NULL,
      unitPrice REAL NOT NULL DEFAULT 0,
      reason TEXT,
      qualityStatus TEXT NOT NULL CHECK(qualityStatus IN ('PENDING', 'APPROVED', 'REJECTED', 'QUARANTINED')) DEFAULT 'PENDING',
      createdAt INTEGER NOT NULL,
      FOREIGN KEY (purchaseReturnId) REFERENCES purchase_returns(id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_purchase_orders_supplier ON purchase_orders(supplierId, orderDate)',
  );
  await db.execute(
    'CREATE INDEX idx_purchase_receipts_order ON purchase_receipts(purchaseOrderId, receiptDate)',
  );
  await db.execute(
    'CREATE INDEX idx_purchase_returns_supplier ON purchase_returns(supplierId, returnDate DESC)',
  );
  await db.execute(
    'CREATE INDEX idx_purchase_return_items_return ON purchase_return_items(purchaseReturnId, qualityStatus)',
  );

  await db.insert('suppliers', {'id': 'legacy-supplier'});
  await db.insert('purchase_requests', {'id': 'legacy-request'});
  await db.insert('warehouses', {'id': 'legacy-warehouse'});
  await db.insert('units', {'id': 'legacy-unit'});
  for (final order in [
    {
      'id': 'legacy-approved-order',
      'orderNumber': 'PO-LEGACY-APPROVED',
      'status': 'CONFIRMED',
      'subtotal': 3300.0,
      'discount': 15.0,
      'tax': 25.0,
      'grandTotal': 3310.0,
    },
    {
      'id': 'legacy-draft-order',
      'orderNumber': 'PO-LEGACY-DRAFT',
      'status': 'DRAFT',
      'subtotal': 540.0,
      'discount': 0.0,
      'tax': 0.0,
      'grandTotal': 540.0,
    },
    {
      'id': 'legacy-fully-received-order',
      'orderNumber': 'PO-LEGACY-FULL',
      'status': 'FULLY_RECEIVED',
      'subtotal': 10.0,
      'discount': 0.0,
      'tax': 0.0,
      'grandTotal': 10.0,
    },
  ]) {
    await db.insert('purchase_orders', {
      ...order,
      'supplierId': 'legacy-supplier',
      'purchaseRequestId': 'legacy-request',
      'orderDate': 1000,
      'expectedDeliveryDate': 2000,
      'notes': 'preserve order note',
      'createdAt': 1100,
      'updatedAt': 1200,
    });
  }
  await db.insert('purchase_order_items', {
    'id': 'legacy-order-line-one',
    'purchaseOrderId': 'legacy-approved-order',
    'itemId': 'legacy-material-one',
    'itemType': 'RAW_MATERIAL',
    'quantity': 100.0,
    'unitId': 'legacy-unit',
    'unitPrice': 27.5,
    'discount': 10.0,
    'tax': 20.0,
    'lineTotal': 2760.0,
    'receivedQuantity': 80.0,
    'notes': 'preserve line one',
  });
  await db.insert('purchase_order_items', {
    'id': 'legacy-order-line-two',
    'purchaseOrderId': 'legacy-approved-order',
    'itemId': 'legacy-material-two',
    'itemType': 'RAW_MATERIAL',
    'quantity': 30.0,
    'unitId': 'legacy-unit',
    'unitPrice': 18.0,
    'discount': 5.0,
    'tax': 5.0,
    'lineTotal': 545.0,
    'receivedQuantity': 0.0,
    'notes': 'preserve line two',
  });
  await db.insert('purchase_receipts', {
    'id': 'legacy-receipt',
    'receiptNumber': 'GR-LEGACY',
    'purchaseOrderId': 'legacy-approved-order',
    'warehouseId': 'legacy-warehouse',
    'receiptDate': 3000,
    'notes': 'preserve receipt note',
    'createdAt': 3100,
    'receivedBy': 'legacy-user',
  });
  await db.insert('purchase_receipt_items', {
    'id': 'legacy-receipt-line',
    'purchaseReceiptId': 'legacy-receipt',
    'purchaseOrderItemId': 'legacy-order-line-one',
    'receivedQuantity': 80.0,
    'unitId': 'legacy-unit',
    'notes': 'preserve receipt line',
  });
  await db.insert('purchase_returns', {
    'id': 'legacy-return',
    'returnNumber': 'PRN-LEGACY',
    'purchaseOrderId': 'legacy-approved-order',
    'purchaseReceiptId': 'legacy-receipt',
    'supplierId': 'legacy-supplier',
    'warehouseId': 'legacy-warehouse',
    'returnDate': 4000,
    'reason': 'preserve return reason',
    'status': 'PENDING',
    'notes': 'preserve return note',
    'createdAt': 4100,
    'updatedAt': 4200,
  });
  await db.insert('purchase_return_items', {
    'id': 'legacy-return-line',
    'purchaseReturnId': 'legacy-return',
    'itemId': 'legacy-material-one',
    'itemType': 'RAW_MATERIAL',
    'quantity': 1.0,
    'unitId': 'legacy-unit',
    'unitPrice': 27.5,
    'reason': 'preserve return line',
    'qualityStatus': 'PENDING',
    'createdAt': 4300,
  });
  await db.execute('PRAGMA user_version = 29');
}
