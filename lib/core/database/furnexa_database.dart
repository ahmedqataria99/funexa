import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/constants/app_constants.dart';

class FurnexaDatabase {
  FurnexaDatabase._();

  static final FurnexaDatabase instance = FurnexaDatabase._();

  static Database? _database;
  static int _testDatabaseSequence = 0;
  static String _databaseFileName = AppConstants.databaseName;
  static String? _testDatabaseDirectory;

  static String get databaseFileName => _databaseFileName;

  static String windowsDatabasePath({
    required String localAppData,
    required String fileName,
  }) => join(localAppData, 'Furnexa', fileName);

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<String> get databasePath async {
    final db = _database;
    return db?.path ?? _resolveDatabasePath();
  }

  Future<int> getDatabaseVersion() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA user_version');
    if (result.isEmpty) {
      return AppConstants.databaseVersion;
    }
    final version = result.first['user_version'];
    return version as int? ?? AppConstants.databaseVersion;
  }

  Future<Database> _openDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await _resolveDatabasePath();
    await Directory(dirname(path)).create(recursive: true);

    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: true,
    );
  }

  Future<String> _resolveDatabasePath() async {
    final testDirectory = _testDatabaseDirectory;
    if (testDirectory != null) {
      return join(testDirectory, _databaseFileName);
    }

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        final stablePath = windowsDatabasePath(
          localAppData: localAppData,
          fileName: _databaseFileName,
        );
        await Directory(dirname(stablePath)).create(recursive: true);
        final stableFile = File(stablePath);
        if (!stableFile.existsSync()) {
          final executableDirectory = dirname(Platform.resolvedExecutable);
          final legacyPaths = [
            join(
              executableDirectory,
              '.dart_tool',
              'sqflite_common_ffi',
              'databases',
              _databaseFileName,
            ),
            join(await getDatabasesPath(), _databaseFileName),
          ];
          for (final legacyPath in legacyPaths) {
            if (normalize(absolute(legacyPath)).toLowerCase() ==
                normalize(absolute(stablePath)).toLowerCase()) {
              continue;
            }
            final legacyFile = File(legacyPath);
            if (!legacyFile.existsSync() || legacyFile.lengthSync() == 0) {
              continue;
            }
            await legacyFile.copy(stablePath);
            final legacyWal = File('$legacyPath-wal');
            if (legacyWal.existsSync()) {
              await legacyWal.copy('$stablePath-wal');
            }
            break;
          }
        }
        return stablePath;
      }
    }

    return join(await getDatabasesPath(), _databaseFileName);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');
    for (
      var migrationVersion = 1;
      migrationVersion <= version;
      migrationVersion++
    ) {
      await _runMigration(db, migrationVersion);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await migrate(db, oldVersion, newVersion);
  }

  Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      for (var version = oldVersion + 1; version <= newVersion; version++) {
        await _runMigration(db, version);
      }
    }
  }

  Future<void> _runMigration(Database db, int version) async {
    switch (version) {
      case 1:
        await db.execute('PRAGMA user_version = 1');
        break;
      case 2:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS factories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            phone TEXT,
            email TEXT,
            address TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS sections (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(factoryId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS workshops (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            sectionId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(sectionId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT,
            FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE RESTRICT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_stages (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            description TEXT,
            sequence INTEGER NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(factoryId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS warehouses (
            id TEXT PRIMARY KEY,
            factoryId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            type TEXT,
            state TEXT NOT NULL DEFAULT 'active',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(factoryId, code),
            FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
          )
        ''');

        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sections_factory_id ON sections(factoryId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_workshops_section_id ON workshops(sectionId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_workshops_factory_id ON workshops(factoryId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_production_stages_factory_id ON production_stages(factoryId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_warehouses_factory_id ON warehouses(factoryId)',
        );
        await db.execute('PRAGMA user_version = 2');
        break;
      case 3:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS units (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            abbreviation TEXT NOT NULL UNIQUE,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS colors (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS raw_materials (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            categoryId TEXT NOT NULL,
            unitId TEXT NOT NULL,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            categoryId TEXT NOT NULL,
            unitId TEXT NOT NULL,
            description TEXT,
            productState TEXT NOT NULL DEFAULT 'unfinished',
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_variants (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            name TEXT NOT NULL,
            code TEXT NOT NULL,
            colorId TEXT,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(productId, code),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (colorId) REFERENCES colors(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_dimensions (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            variantId TEXT,
            length REAL,
            width REAL,
            height REAL,
            unit TEXT,
            UNIQUE(productId, variantId),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (variantId) REFERENCES product_variants(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_bom_items (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            notes TEXT,
            UNIQUE(productId, rawMaterialId),
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_raw_materials_category ON raw_materials(categoryId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_raw_materials_unit ON raw_materials(unitId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_category ON products(categoryId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_products_unit ON products(unitId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_variants_product ON product_variants(productId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_dimensions_product ON product_dimensions(productId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_dimensions_variant ON product_dimensions(variantId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_bom_product ON product_bom_items(productId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_bom_material ON product_bom_items(rawMaterialId)',
        );
        await db.execute('PRAGMA user_version = 3');
        break;
      case 4:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_balances (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL', 'PRODUCT')),
            quantity REAL NOT NULL CHECK(quantity >= 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(warehouseId, itemId, itemType),
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_transactions (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL', 'PRODUCT')),
            transactionType TEXT NOT NULL CHECK(transactionType IN ('STOCK_IN', 'STOCK_OUT', 'TRANSFER_IN', 'TRANSFER_OUT', 'ADJUSTMENT')),
            quantity REAL NOT NULL,
            unitId TEXT NOT NULL,
            reference TEXT,
            notes TEXT,
            transactionDate INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_balances_warehouse ON stock_balances(warehouseId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_balances_item ON stock_balances(itemId, itemType)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_transactions_warehouse ON stock_transactions(warehouseId, transactionDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_transactions_item ON stock_transactions(itemId, itemType, transactionDate)',
        );
        await db.execute('PRAGMA user_version = 4');
        break;
      case 5:
        await _runMigration(db, 2);
        await _runMigration(db, 3);
        await _runMigration(db, 4);
        await db.execute('PRAGMA user_version = 5');
        break;
      case 6:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS suppliers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            phone TEXT,
            email TEXT,
            address TEXT,
            taxNumber TEXT,
            notes TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_requests (
            id TEXT PRIMARY KEY,
            requestNumber TEXT NOT NULL UNIQUE,
            requestDate INTEGER NOT NULL,
            requestedBy TEXT NOT NULL,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','PENDING','APPROVED','REJECTED','CONVERTED','CANCELLED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_request_items (
            id TEXT PRIMARY KEY,
            purchaseRequestId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL','PRODUCT')),
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            notes TEXT,
            UNIQUE(purchaseRequestId, itemId, itemType),
            FOREIGN KEY (purchaseRequestId) REFERENCES purchase_requests(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_orders (
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
          CREATE TABLE IF NOT EXISTS purchase_order_items (
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
          CREATE TABLE IF NOT EXISTS purchase_receipts (
            id TEXT PRIMARY KEY,
            receiptNumber TEXT NOT NULL UNIQUE,
            purchaseOrderId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            receiptDate INTEGER NOT NULL,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (purchaseOrderId) REFERENCES purchase_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_receipt_items (
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
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier ON purchase_orders(supplierId, orderDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_purchase_requests_status ON purchase_requests(status, requestDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_purchase_receipts_order ON purchase_receipts(purchaseOrderId, receiptDate)',
        );
        await db.execute('PRAGMA user_version = 6');
        break;
      case 7:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customers (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, code TEXT NOT NULL UNIQUE,
            phone TEXT, email TEXT, address TEXT, taxNumber TEXT, notes TEXT,
            active INTEGER NOT NULL DEFAULT 1, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS quotations (
            id TEXT PRIMARY KEY, quotationNumber TEXT NOT NULL UNIQUE, customerId TEXT NOT NULL,
            quotationDate INTEGER NOT NULL, validUntil INTEGER,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','SENT','ACCEPTED','REJECTED','EXPIRED','CONVERTED','CANCELLED')),
            subtotal REAL NOT NULL DEFAULT 0, discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0,
            grandTotal REAL NOT NULL DEFAULT 0, notes TEXT, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS quotation_items (
            id TEXT PRIMARY KEY, quotationId TEXT NOT NULL, itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT','RAW_MATERIAL')),
            quantity REAL NOT NULL CHECK(quantity > 0), unitId TEXT NOT NULL, unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0, lineTotal REAL NOT NULL DEFAULT 0, notes TEXT,
            UNIQUE(quotationId, itemId, itemType), FOREIGN KEY (quotationId) REFERENCES quotations(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_orders (
            id TEXT PRIMARY KEY, orderNumber TEXT NOT NULL UNIQUE, customerId TEXT NOT NULL, quotationId TEXT,
            orderDate INTEGER NOT NULL, expectedDeliveryDate INTEGER,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','CONFIRMED','PARTIALLY_DELIVERED','FULLY_DELIVERED','CANCELLED')),
            subtotal REAL NOT NULL DEFAULT 0, discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0,
            grandTotal REAL NOT NULL DEFAULT 0, notes TEXT, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (quotationId) REFERENCES quotations(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_order_items (
            id TEXT PRIMARY KEY, salesOrderId TEXT NOT NULL, itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT','RAW_MATERIAL')),
            quantity REAL NOT NULL CHECK(quantity > 0), unitId TEXT NOT NULL, unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0, lineTotal REAL NOT NULL DEFAULT 0,
            deliveredQuantity REAL NOT NULL DEFAULT 0 CHECK(deliveredQuantity >= 0), notes TEXT,
            UNIQUE(salesOrderId, itemId, itemType), FOREIGN KEY (salesOrderId) REFERENCES sales_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_deliveries (
            id TEXT PRIMARY KEY, deliveryNumber TEXT NOT NULL UNIQUE, salesOrderId TEXT NOT NULL, warehouseId TEXT NOT NULL,
            deliveryDate INTEGER NOT NULL, notes TEXT, createdAt INTEGER NOT NULL,
            FOREIGN KEY (salesOrderId) REFERENCES sales_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_delivery_items (
            id TEXT PRIMARY KEY, salesDeliveryId TEXT NOT NULL, salesOrderItemId TEXT NOT NULL,
            deliveredQuantity REAL NOT NULL CHECK(deliveredQuantity > 0), unitId TEXT NOT NULL, notes TEXT,
            FOREIGN KEY (salesDeliveryId) REFERENCES sales_deliveries(id) ON DELETE RESTRICT,
            FOREIGN KEY (salesOrderItemId) REFERENCES sales_order_items(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_quotations_customer ON quotations(customerId, quotationDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_orders_customer ON sales_orders(customerId, orderDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_deliveries_order ON sales_deliveries(salesOrderId, deliveryDate)',
        );
        await db.execute('PRAGMA user_version = 7');
        break;
      case 8:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_routes (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL UNIQUE,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_route_stages (
            id TEXT PRIMARY KEY,
            routeId TEXT NOT NULL,
            productionStageId TEXT NOT NULL,
            sequence INTEGER NOT NULL CHECK(sequence > 0),
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(routeId, productionStageId),
            UNIQUE(routeId, sequence),
            FOREIGN KEY (routeId) REFERENCES production_routes(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_orders (
            id TEXT PRIMARY KEY,
            orderNumber TEXT NOT NULL UNIQUE,
            productId TEXT NOT NULL,
            variantId TEXT,
            routeId TEXT NOT NULL,
            plannedQuantity REAL NOT NULL CHECK(plannedQuantity > 0),
            producedQuantity REAL NOT NULL DEFAULT 0 CHECK(producedQuantity >= 0),
            status TEXT NOT NULL CHECK(status IN ('DRAFT','PLANNED','IN_PROGRESS','COMPLETED','CANCELLED')),
            startDate INTEGER,
            completionDate INTEGER,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (variantId) REFERENCES product_variants(id) ON DELETE RESTRICT,
            FOREIGN KEY (routeId) REFERENCES production_routes(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_order_stages (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            productionStageId TEXT NOT NULL,
            sequence INTEGER NOT NULL CHECK(sequence > 0),
            status TEXT NOT NULL CHECK(status IN ('PENDING','IN_PROGRESS','COMPLETED','SKIPPED')),
            startedAt INTEGER,
            completedAt INTEGER,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(productionOrderId, productionStageId),
            UNIQUE(productionOrderId, sequence),
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_material_consumptions (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            consumptionDate INTEGER NOT NULL,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_waste (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            reason TEXT NOT NULL,
            notes TEXT,
            wasteDate INTEGER NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_outputs (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            unitId TEXT NOT NULL,
            outputDate INTEGER NOT NULL,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_production_routes_product ON production_routes(productId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_production_orders_status ON production_orders(status, createdAt)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_production_order_stages_order ON production_order_stages(productionOrderId, sequence)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_production_consumptions_order ON production_material_consumptions(productionOrderId, consumptionDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_production_waste_order ON production_waste(productionOrderId, wasteDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_production_outputs_order ON production_outputs(productionOrderId, outputDate)',
        );
        await db.execute('PRAGMA user_version = 8');
        break;
      case 9:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS workers (
            id TEXT PRIMARY KEY,
            employeeCode TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            address TEXT,
            hireDate INTEGER NOT NULL,
            sectionId TEXT,
            workshopId TEXT,
            productionStageId TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            basicSalary REAL NOT NULL CHECK(basicSalary >= 0),
            salaryType TEXT NOT NULL CHECK(salaryType IN ('MONTHLY','DAILY','HOURLY')),
            overtimeEnabled INTEGER NOT NULL DEFAULT 0,
            overtimeRateOverride REAL,
            notes TEXT,
            annualLeaveAllowance REAL NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE RESTRICT,
            FOREIGN KEY (workshopId) REFERENCES workshops(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shifts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            graceMinutes INTEGER NOT NULL DEFAULT 0 CHECK(graceMinutes >= 0),
            overtimeEnabled INTEGER NOT NULL DEFAULT 0,
            overtimeStartAfterMinutes INTEGER NOT NULL DEFAULT 0 CHECK(overtimeStartAfterMinutes >= 0),
            overtimeRate REAL NOT NULL DEFAULT 0 CHECK(overtimeRate >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS worker_assignments (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            sectionId TEXT,
            workshopId TEXT,
            productionStageId TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(workerId),
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT,
            FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE RESTRICT,
            FOREIGN KEY (workshopId) REFERENCES workshops(id) ON DELETE RESTRICT,
            FOREIGN KEY (productionStageId) REFERENCES production_stages(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS attendance_records (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            shiftId TEXT NOT NULL,
            workDate INTEGER NOT NULL,
            checkIn INTEGER,
            checkOut INTEGER,
            regularHours REAL NOT NULL DEFAULT 0 CHECK(regularHours >= 0),
            overtimeHours REAL NOT NULL DEFAULT 0 CHECK(overtimeHours >= 0),
            overtimeRate REAL NOT NULL DEFAULT 0 CHECK(overtimeRate >= 0),
            overtimeAmount REAL NOT NULL DEFAULT 0 CHECK(overtimeAmount >= 0),
            lateMinutes INTEGER NOT NULL DEFAULT 0 CHECK(lateMinutes >= 0),
            earlyLeaveMinutes INTEGER NOT NULL DEFAULT 0 CHECK(earlyLeaveMinutes >= 0),
            status TEXT NOT NULL CHECK(status IN ('PRESENT','ABSENT','LEAVE','OFF_DAY','PARTIAL')),
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(workerId, workDate),
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT,
            FOREIGN KEY (shiftId) REFERENCES shifts(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS leave_records (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            leaveType TEXT NOT NULL CHECK(leaveType IN ('ANNUAL','SICK','UNPAID','OTHER')),
            startDate INTEGER NOT NULL,
            endDate INTEGER NOT NULL,
            days INTEGER NOT NULL CHECK(days >= 0),
            reason TEXT,
            status TEXT NOT NULL CHECK(status IN ('PENDING','APPROVED','REJECTED','CANCELLED')),
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS deductions (
            id TEXT PRIMARY KEY,
            workerId TEXT NOT NULL,
            date INTEGER NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('LATE','ABSENCE','MANUAL','OTHER')),
            amount REAL NOT NULL CHECK(amount >= 0),
            reason TEXT,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('PENDING','APPROVED','REJECTED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS payroll_periods (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            startDate INTEGER NOT NULL,
            endDate INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','CALCULATED','APPROVED','PAID')) DEFAULT 'DRAFT',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS payroll_records (
            id TEXT PRIMARY KEY,
            payrollPeriodId TEXT NOT NULL,
            workerId TEXT NOT NULL,
            basicSalary REAL NOT NULL CHECK(basicSalary >= 0),
            regularEarnings REAL NOT NULL CHECK(regularEarnings >= 0),
            overtimeHours REAL NOT NULL DEFAULT 0 CHECK(overtimeHours >= 0),
            overtimeAmount REAL NOT NULL DEFAULT 0 CHECK(overtimeAmount >= 0),
            deductionsAmount REAL NOT NULL DEFAULT 0 CHECK(deductionsAmount >= 0),
            grossSalary REAL NOT NULL CHECK(grossSalary >= 0),
            netSalary REAL NOT NULL CHECK(netSalary >= 0),
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','CALCULATED','APPROVED','PAID')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(payrollPeriodId, workerId),
            FOREIGN KEY (payrollPeriodId) REFERENCES payroll_periods(id) ON DELETE RESTRICT,
            FOREIGN KEY (workerId) REFERENCES workers(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_workers_active ON workers(active, name)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_workers_section ON workers(sectionId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_workers_workshop ON workers(workshopId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_attendance_worker_date ON attendance_records(workerId, workDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_leave_worker_dates ON leave_records(workerId, startDate, endDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_payroll_period_worker ON payroll_records(payrollPeriodId, workerId)',
        );
        await db.execute('PRAGMA user_version = 9');
        break;
      case 10:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE')),
            parentId TEXT,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            systemAccount INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (parentId) REFERENCES accounts(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS accounting_periods (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            startDate INTEGER NOT NULL,
            endDate INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('OPEN','CLOSED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            CHECK(endDate >= startDate)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS journal_entries (
            id TEXT PRIMARY KEY,
            entryNumber TEXT NOT NULL UNIQUE,
            date INTEGER NOT NULL,
            description TEXT NOT NULL,
            referenceType TEXT,
            referenceId TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(referenceType, referenceId)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS journal_lines (
            id TEXT PRIMARY KEY,
            journalEntryId TEXT NOT NULL,
            accountId TEXT NOT NULL,
            debit REAL NOT NULL DEFAULT 0 CHECK(debit >= 0),
            credit REAL NOT NULL DEFAULT 0 CHECK(credit >= 0),
            description TEXT,
            FOREIGN KEY (journalEntryId) REFERENCES journal_entries(id) ON DELETE RESTRICT,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT,
            CHECK((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS journal_parties (
            journalEntryId TEXT PRIMARY KEY,
            partyType TEXT NOT NULL CHECK(partyType IN ('CUSTOMER','SUPPLIER','WORKER')),
            partyId TEXT NOT NULL,
            FOREIGN KEY (journalEntryId) REFERENCES journal_entries(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cashboxes (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT NOT NULL UNIQUE,
            accountId TEXT NOT NULL,
            openingBalance REAL NOT NULL DEFAULT 0 CHECK(openingBalance >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bank_accounts (
            id TEXT PRIMARY KEY,
            bankName TEXT NOT NULL,
            accountName TEXT NOT NULL,
            accountNumber TEXT NOT NULL,
            accountId TEXT NOT NULL,
            openingBalance REAL NOT NULL DEFAULT 0 CHECK(openingBalance >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customer_payments (
            id TEXT PRIMARY KEY,
            customerId TEXT NOT NULL,
            date INTEGER NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            cashboxId TEXT,
            bankAccountId TEXT,
            reference TEXT,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (cashboxId) REFERENCES cashboxes(id) ON DELETE RESTRICT,
            FOREIGN KEY (bankAccountId) REFERENCES bank_accounts(id) ON DELETE RESTRICT,
            CHECK((cashboxId IS NOT NULL AND bankAccountId IS NULL) OR (cashboxId IS NULL AND bankAccountId IS NOT NULL))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS supplier_payments (
            id TEXT PRIMARY KEY,
            supplierId TEXT NOT NULL,
            date INTEGER NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            cashboxId TEXT,
            bankAccountId TEXT,
            reference TEXT,
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id) ON DELETE RESTRICT,
            FOREIGN KEY (cashboxId) REFERENCES cashboxes(id) ON DELETE RESTRICT,
            FOREIGN KEY (bankAccountId) REFERENCES bank_accounts(id) ON DELETE RESTRICT,
            CHECK((cashboxId IS NOT NULL AND bankAccountId IS NULL) OR (cashboxId IS NULL AND bankAccountId IS NOT NULL))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expenses (
            id TEXT PRIMARY KEY,
            expenseNumber TEXT NOT NULL UNIQUE,
            date INTEGER NOT NULL,
            accountId TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            cashboxId TEXT,
            bankAccountId TEXT,
            description TEXT NOT NULL,
            reference TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT','POSTED','REVERSED')),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (accountId) REFERENCES accounts(id) ON DELETE RESTRICT,
            FOREIGN KEY (cashboxId) REFERENCES cashboxes(id) ON DELETE RESTRICT,
            FOREIGN KEY (bankAccountId) REFERENCES bank_accounts(id) ON DELETE RESTRICT,
            CHECK((cashboxId IS NOT NULL AND bankAccountId IS NULL) OR (cashboxId IS NULL AND bankAccountId IS NOT NULL))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory_valuations (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL','PRODUCT')),
            quantity REAL NOT NULL DEFAULT 0 CHECK(quantity >= 0),
            averageCost REAL NOT NULL DEFAULT 0 CHECK(averageCost >= 0),
            updatedAt INTEGER NOT NULL,
            UNIQUE(warehouseId, itemId, itemType),
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_accounts_parent ON accounts(parentId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(accountId, journalEntryId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_parties_party ON journal_parties(partyType, partyId, journalEntryId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(date, status)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_period_dates ON accounting_periods(startDate, endDate, status)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_inventory_valuations_item ON inventory_valuations(warehouseId, itemId, itemType)',
        );
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final defaults = [
          ['1000', 'النقدية', 'ASSET', 'Cash', 1],
          ['1010', 'البنوك', 'ASSET', 'Bank', 1],
          ['1100', 'المخزون', 'ASSET', 'Inventory', 1],
          ['1200', 'العملاء', 'ASSET', 'Accounts Receivable', 1],
          ['2000', 'الموردون', 'LIABILITY', 'Accounts Payable', 1],
          ['2010', 'مستحقات الرواتب', 'LIABILITY', 'Salary Payable', 1],
          ['3000', 'رأس المال', 'EQUITY', 'Capital', 0],
          ['3100', 'الأرباح المحتجزة', 'EQUITY', 'Retained Earnings', 0],
          ['4000', 'إيرادات المبيعات', 'REVENUE', 'Sales Revenue', 1],
          ['5000', 'تكلفة المبيعات', 'EXPENSE', 'COGS', 1],
          ['5100', 'مصروف الرواتب', 'EXPENSE', 'Salaries', 1],
          ['5900', 'المصروفات العامة', 'EXPENSE', 'General Expenses', 1],
          ['5910', 'تسويات المخزون', 'REVENUE', 'Inventory Adjustment', 1],
          ['5920', 'فاقد المخزون', 'EXPENSE', 'Inventory Loss', 1],
        ];
        for (final account in defaults) {
          await db.insert('accounts', {
            'id': 'system-${account[0]}',
            'code': account[0],
            'name': account[1],
            'type': account[2],
            'description': account[3],
            'systemAccount': account[4],
            'createdAt': stamp,
            'updatedAt': stamp,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await db.execute('PRAGMA user_version = 10');
        break;
      case 11:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS roles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            active INTEGER NOT NULL DEFAULT 1,
            isSystemRole INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS permissions (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            module TEXT NOT NULL,
            action TEXT NOT NULL,
            description TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT NOT NULL UNIQUE,
            displayName TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            passwordHash TEXT NOT NULL,
            roleId TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            lastLoginAt INTEGER,
            FOREIGN KEY (roleId) REFERENCES roles(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS role_permissions (
            roleId TEXT NOT NULL,
            permissionId TEXT NOT NULL,
            PRIMARY KEY(roleId, permissionId),
            FOREIGN KEY (roleId) REFERENCES roles(id) ON DELETE RESTRICT,
            FOREIGN KEY (permissionId) REFERENCES permissions(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_scopes (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            scopeType TEXT NOT NULL CHECK(scopeType IN ('SECTION','WORKSHOP','WAREHOUSE','PRODUCTION_STAGE')),
            scopeId TEXT NOT NULL,
            UNIQUE(userId, scopeType, scopeId),
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audit_logs (
            id TEXT PRIMARY KEY,
            userId TEXT,
            usernameSnapshot TEXT NOT NULL,
            action TEXT NOT NULL,
            module TEXT NOT NULL,
            entityType TEXT NOT NULL,
            entityId TEXT,
            timestamp INTEGER NOT NULL,
            oldValue TEXT,
            newValue TEXT,
            description TEXT,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE SET NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_logs(timestamp DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_audit_user_module ON audit_logs(userId, module, action)',
        );
        await db.execute(
          "CREATE TRIGGER IF NOT EXISTS prevent_audit_update BEFORE UPDATE ON audit_logs BEGIN SELECT RAISE(ABORT, 'audit logs are immutable'); END",
        );
        await db.execute(
          "CREATE TRIGGER IF NOT EXISTS prevent_audit_delete BEFORE DELETE ON audit_logs BEGIN SELECT RAISE(ABORT, 'audit logs are immutable'); END",
        );
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await db.insert('roles', {
          'id': 'role-system-admin',
          'name': 'System Admin',
          'description': 'Full system access',
          'isSystemRole': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        const permissionData = [
          ['SYSTEM_ADMIN', 'System', 'ALL'],
          ['FACTORY_VIEW', 'Factory', 'VIEW'],
          ['FACTORY_EDIT', 'Factory', 'EDIT'],
          ['PRODUCTS_VIEW', 'Products', 'VIEW'],
          ['PRODUCTS_EDIT', 'Products', 'EDIT'],
          ['WAREHOUSE_STOCK_VIEW', 'Warehouse', 'VIEW'],
          ['WAREHOUSE_STOCK_EDIT', 'Warehouse', 'EDIT'],
          ['PURCHASING_VIEW', 'Purchasing', 'VIEW'],
          ['PURCHASING_RECEIVE', 'Purchasing', 'RECEIVE'],
          ['PRICING_VIEW', 'Pricing', 'VIEW'],
          ['PRICING_EDIT', 'Pricing', 'EDIT'],
          ['SALES_VIEW', 'Sales', 'VIEW'],
          ['SALES_DELIVER', 'Sales', 'DELIVER'],
          ['CRM_VIEW', 'CRM', 'VIEW'],
          ['CRM_EDIT', 'CRM', 'EDIT'],
          ['PRODUCTION_VIEW', 'Production', 'VIEW'],
          ['PRODUCTION_EDIT', 'Production', 'EDIT'],
          ['HR_VIEW', 'HR', 'VIEW'],
          ['HR_EDIT', 'HR', 'EDIT'],
          ['HR_PAYROLL_APPROVE', 'HR', 'PAYROLL_APPROVE'],
          ['ACCOUNTING_VIEW', 'Accounting', 'VIEW'],
          ['ACCOUNTING_POST', 'Accounting', 'POST'],
          ['ACCOUNTING_REVERSE', 'Accounting', 'REVERSE'],
          ['ACCOUNTING_CLOSE_PERIOD', 'Accounting', 'CLOSE_PERIOD'],
          ['USERS_VIEW', 'Users', 'VIEW'],
          ['USERS_EDIT', 'Users', 'EDIT'],
          ['ROLES_EDIT', 'Roles', 'EDIT'],
          ['AUDIT_VIEW', 'Audit', 'VIEW'],
        ];
        for (final permission in permissionData) {
          await db.insert('permissions', {
            'id': 'permission-${permission[0]}',
            'code': permission[0],
            'module': permission[1],
            'action': permission[2],
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('role_permissions', {
            'roleId': 'role-system-admin',
            'permissionId': 'permission-${permission[0]}',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await db.execute('PRAGMA user_version = 11');
        break;
      case 12:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_minimum_levels (
            id TEXT PRIMARY KEY,
            warehouseId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('RAW_MATERIAL', 'PRODUCT')),
            minimumQuantity REAL NOT NULL CHECK(minimumQuantity >= 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(warehouseId, itemId, itemType),
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notifications (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            severity TEXT NOT NULL CHECK(severity IN ('INFO', 'SUCCESS', 'WARNING', 'CRITICAL')),
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            isRead INTEGER NOT NULL DEFAULT 0,
            isArchived INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            readAt INTEGER,
            archivedAt INTEGER,
            relatedEntityType TEXT,
            relatedEntityId TEXT,
            actionKey TEXT,
            deduplicationKey TEXT NOT NULL,
            UNIQUE(userId, deduplicationKey),
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(userId, isRead, isArchived)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(createdAt DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notifications_dedup ON notifications(deduplicationKey)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_minimum_warehouse ON stock_minimum_levels(warehouseId, itemId, itemType)',
        );
        await db.execute('PRAGMA user_version = 12');
        break;
      case 13:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS document_sequences (
            id TEXT PRIMARY KEY,
            documentType TEXT NOT NULL,
            year INTEGER NOT NULL,
            lastNumber INTEGER NOT NULL DEFAULT 0 CHECK(lastNumber >= 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(documentType, year)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS document_records (
            documentId TEXT PRIMARY KEY,
            documentType TEXT NOT NULL,
            documentNumber TEXT NOT NULL UNIQUE,
            issueDate INTEGER NOT NULL,
            title TEXT NOT NULL,
            language TEXT NOT NULL CHECK(language IN ('ar', 'en')),
            templateType TEXT NOT NULL CHECK(templateType IN ('STANDARD', 'COMPACT', 'THERMAL')),
            status TEXT NOT NULL CHECK(status IN ('DRAFT', 'POSTED', 'CANCELLED')),
            sourceEntityType TEXT,
            sourceEntityId TEXT,
            factoryId TEXT,
            createdBy TEXT,
            createdAt INTEGER NOT NULL,
            metadata TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_records_type_date ON document_records(documentType, issueDate DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_records_source ON document_records(sourceEntityType, sourceEntityId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_sequences_type_year ON document_sequences(documentType, year)',
        );
        await db.execute('PRAGMA user_version = 13');
        break;
      case 14:
        await db.execute(
          "ALTER TABLE sales_deliveries ADD COLUMN status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'))",
        );
        await db.execute(
          'ALTER TABLE sales_deliveries ADD COLUMN dispatchDate INTEGER',
        );
        await db.execute(
          'ALTER TABLE sales_deliveries ADD COLUMN driverName TEXT',
        );
        await db.execute(
          'ALTER TABLE sales_deliveries ADD COLUMN vehicleNumber TEXT',
        );
        await db.execute(
          'ALTER TABLE sales_deliveries ADD COLUMN destination TEXT',
        );
        await db.execute(
          'ALTER TABLE sales_deliveries ADD COLUMN updatedAt INTEGER',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_deliveries_status ON sales_deliveries(status, deliveryDate)',
        );
        await db.execute('PRAGMA user_version = 14');
        break;
      case 15:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pricing_lists (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            description TEXT,
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS price_lists (
            id TEXT PRIMARY KEY,
            code TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            description TEXT,
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_prices (
            id TEXT PRIMARY KEY,
            priceListId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId),
            FOREIGN KEY (priceListId) REFERENCES pricing_lists(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pricing_product_prices (
            id TEXT PRIMARY KEY,
            priceListId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId),
            FOREIGN KEY (priceListId) REFERENCES pricing_lists(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customer_price_overrides (
            id TEXT PRIMARY KEY,
            customerId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(customerId, productId, variantId),
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customer_prices (
            id TEXT PRIMARY KEY,
            customerId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            currency TEXT NOT NULL DEFAULT 'SAR',
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(customerId, productId, variantId),
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS price_tiers (
            id TEXT PRIMARY KEY,
            priceListId TEXT,
            productId TEXT NOT NULL,
            variantId TEXT,
            minimumQuantity REAL NOT NULL CHECK(minimumQuantity >= 0),
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId, minimumQuantity)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pricing_tiers (
            id TEXT PRIMARY KEY,
            priceListId TEXT,
            productId TEXT NOT NULL,
            variantId TEXT,
            minimumQuantity REAL NOT NULL CHECK(minimumQuantity >= 0),
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(priceListId, productId, variantId, minimumQuantity)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS discount_rules (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            productId TEXT,
            variantId TEXT,
            type TEXT NOT NULL CHECK(type IN ('percentage', 'amount')),
            value REAL NOT NULL CHECK(value >= 0),
            minimumQuantity REAL NOT NULL DEFAULT 0 CHECK(minimumQuantity >= 0),
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS commercial_discount_rules (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            productId TEXT,
            variantId TEXT,
            type TEXT NOT NULL CHECK(type IN ('percentage', 'amount')),
            value REAL NOT NULL CHECK(value >= 0),
            minimumQuantity REAL NOT NULL DEFAULT 0 CHECK(minimumQuantity >= 0),
            validFrom INTEGER,
            validTo INTEGER,
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS price_history (
            id TEXT PRIMARY KEY,
            entityType TEXT NOT NULL,
            entityId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discountAmount REAL NOT NULL DEFAULT 0,
            finalPrice REAL NOT NULL CHECK(finalPrice >= 0),
            effectiveAt INTEGER NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS pricing_history (
            id TEXT PRIMARY KEY,
            entityType TEXT NOT NULL,
            entityId TEXT NOT NULL,
            productId TEXT NOT NULL,
            variantId TEXT,
            unitPrice REAL NOT NULL CHECK(unitPrice >= 0),
            discountAmount REAL NOT NULL DEFAULT 0,
            finalPrice REAL NOT NULL CHECK(finalPrice >= 0),
            effectiveAt INTEGER NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_product_prices_list ON product_prices(priceListId, productId, variantId, active)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_customer_prices_customer ON customer_price_overrides(customerId, productId, variantId, active)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_price_tiers_product ON price_tiers(productId, variantId, minimumQuantity)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_discount_rules_scope ON discount_rules(customerId, productId, variantId, minimumQuantity, active)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_price_history_product ON price_history(productId, effectiveAt DESC)',
        );
        await db.insert('permissions', {
          'id': 'permission-PRICING_VIEW',
          'code': 'PRICING_VIEW',
          'module': 'Pricing',
          'action': 'VIEW',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await db.insert('permissions', {
          'id': 'permission-PRICING_EDIT',
          'code': 'PRICING_EDIT',
          'module': 'Pricing',
          'action': 'EDIT',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await db.rawInsert(
          "INSERT OR IGNORE INTO role_permissions (roleId, permissionId) SELECT 'role-system-admin', id FROM permissions WHERE code IN ('PRICING_VIEW', 'PRICING_EDIT')",
        );
        await db.execute('PRAGMA user_version = 15');
        break;
      case 16:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_returns (
            id TEXT PRIMARY KEY,
            returnNumber TEXT NOT NULL UNIQUE,
            salesOrderId TEXT NOT NULL,
            salesDeliveryId TEXT,
            customerId TEXT NOT NULL,
            warehouseId TEXT NOT NULL,
            returnDate INTEGER NOT NULL,
            reason TEXT,
            status TEXT NOT NULL CHECK(status IN ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'COMPLETED', 'CANCELLED')) DEFAULT 'PENDING',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (salesOrderId) REFERENCES sales_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (warehouseId) REFERENCES warehouses(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales_return_items (
            id TEXT PRIMARY KEY,
            salesReturnId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
            quantity REAL NOT NULL CHECK(quantity >= 0),
            unitId TEXT NOT NULL,
            unitPrice REAL NOT NULL DEFAULT 0,
            reason TEXT,
            qualityStatus TEXT NOT NULL CHECK(qualityStatus IN ('PENDING', 'APPROVED', 'REJECTED', 'QUARANTINED')) DEFAULT 'PENDING',
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (salesReturnId) REFERENCES sales_returns(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_returns (
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
          CREATE TABLE IF NOT EXISTS purchase_return_items (
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
        await db.execute('''
          CREATE TABLE IF NOT EXISTS quality_inspections (
            id TEXT PRIMARY KEY,
            inspectionNumber TEXT NOT NULL UNIQUE,
            sourceType TEXT NOT NULL,
            sourceId TEXT NOT NULL,
            warehouseId TEXT,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
            inspectedBy TEXT,
            inspectionDate INTEGER NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'QUARANTINED')) DEFAULT 'PENDING',
            result TEXT NOT NULL CHECK(result IN ('PASSED', 'FAILED', 'QUARANTINED', 'REJECTED')) DEFAULT 'PASSED',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS quality_inspection_items (
            id TEXT PRIMARY KEY,
            inspectionId TEXT NOT NULL,
            itemId TEXT NOT NULL,
            itemType TEXT NOT NULL CHECK(itemType IN ('PRODUCT', 'RAW_MATERIAL')),
            requestedQuantity REAL NOT NULL CHECK(requestedQuantity >= 0),
            inspectedQuantity REAL NOT NULL CHECK(inspectedQuantity >= 0),
            acceptedQuantity REAL NOT NULL CHECK(acceptedQuantity >= 0),
            rejectedQuantity REAL NOT NULL CHECK(rejectedQuantity >= 0),
            result TEXT NOT NULL CHECK(result IN ('PASSED', 'FAILED', 'QUARANTINED', 'REJECTED')) DEFAULT 'PASSED',
            notes TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (inspectionId) REFERENCES quality_inspections(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_returns_customer ON sales_returns(customerId, returnDate DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_return_items_return ON sales_return_items(salesReturnId, qualityStatus)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_purchase_returns_supplier ON purchase_returns(supplierId, returnDate DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_purchase_return_items_return ON purchase_return_items(purchaseReturnId, qualityStatus)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_quality_inspections_source ON quality_inspections(sourceType, sourceId, inspectionDate DESC)',
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-RETURNS_VIEW', 'RETURNS_VIEW', 'Returns', 'VIEW')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-RETURNS_EDIT', 'RETURNS_EDIT', 'Returns', 'EDIT')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-QUALITY_VIEW', 'QUALITY_VIEW', 'Quality', 'VIEW')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-QUALITY_EDIT', 'QUALITY_EDIT', 'Quality', 'EDIT')",
        );
        await db.rawInsert(
          "INSERT OR IGNORE INTO role_permissions (roleId, permissionId) SELECT 'role-system-admin', id FROM permissions WHERE code IN ('RETURNS_VIEW', 'RETURNS_EDIT', 'QUALITY_VIEW', 'QUALITY_EDIT')",
        );
        await db.execute('PRAGMA user_version = 16');
        break;
      case 17:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS crm_leads (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            email TEXT,
            company TEXT,
            address TEXT,
            source TEXT NOT NULL CHECK(source IN ('WEBSITE','FACEBOOK','INSTAGRAM','REFERRAL','WALK_IN','OTHER')),
            notes TEXT,
            status TEXT NOT NULL CHECK(status IN ('NEW','CONTACTED','QUALIFIED','CONVERTED','LOST')),
            assignedUserId TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            convertedAt INTEGER,
            convertedCustomerId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS crm_activities (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            type TEXT NOT NULL CHECK(type IN ('CALL','MEETING','WHATSAPP','EMAIL','VISIT','NOTE','OTHER')),
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            activityDate INTEGER NOT NULL,
            createdBy TEXT NOT NULL,
            relatedDocumentId TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS crm_follow_ups (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dueDate INTEGER NOT NULL,
            assignedUserId TEXT NOT NULL,
            priority TEXT NOT NULL CHECK(priority IN ('LOW','MEDIUM','HIGH')),
            status TEXT NOT NULL CHECK(status IN ('PENDING','COMPLETED','CANCELLED')),
            completedAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS crm_tasks (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            assignedUserId TEXT NOT NULL,
            dueDate INTEGER NOT NULL,
            priority TEXT NOT NULL CHECK(priority IN ('LOW','MEDIUM','HIGH')),
            status TEXT NOT NULL CHECK(status IN ('PENDING','COMPLETED','CANCELLED')),
            completedAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS crm_notes (
            id TEXT PRIMARY KEY,
            customerId TEXT,
            leadId TEXT,
            content TEXT NOT NULL,
            createdBy TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (leadId) REFERENCES crm_leads(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_crm_leads_status ON crm_leads(status, updatedAt DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_crm_follow_ups_due ON crm_follow_ups(status, dueDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_crm_tasks_due ON crm_tasks(status, dueDate)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_crm_activities_customer ON crm_activities(customerId, activityDate DESC)',
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-CRM_VIEW', 'CRM_VIEW', 'CRM', 'VIEW')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-CRM_EDIT', 'CRM_EDIT', 'CRM', 'EDIT')",
        );
        await db.rawInsert(
          "INSERT OR IGNORE INTO role_permissions (roleId, permissionId) SELECT 'role-system-admin', id FROM permissions WHERE code IN ('CRM_VIEW', 'CRM_EDIT')",
        );
        await db.execute('PRAGMA user_version = 17');
        break;
      case 18:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS costing_overhead_rules (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            calculationType TEXT NOT NULL CHECK(calculationType IN ('PERCENTAGE')),
            rate REAL NOT NULL DEFAULT 0 CHECK(rate >= 0),
            base TEXT NOT NULL CHECK(base IN ('MATERIAL_COST', 'LABOR_COST', 'MATERIAL_PLUS_LABOR')),
            active INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_other_costs (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            description TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount >= 0),
            date INTEGER NOT NULL,
            createdBy TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_cost_adjustments (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            productId TEXT NOT NULL,
            adjustmentType TEXT NOT NULL CHECK(adjustmentType IN ('INCREASE', 'DECREASE')),
            amount REAL NOT NULL CHECK(amount >= 0),
            reason TEXT NOT NULL,
            createdBy TEXT,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_batch_costs (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL UNIQUE,
            productId TEXT NOT NULL,
            plannedQuantity REAL NOT NULL DEFAULT 0 CHECK(plannedQuantity >= 0),
            goodFinishedQuantity REAL NOT NULL DEFAULT 0 CHECK(goodFinishedQuantity >= 0),
            materialCost REAL NOT NULL DEFAULT 0,
            laborCost REAL NOT NULL DEFAULT 0,
            overheadCost REAL NOT NULL DEFAULT 0,
            otherCost REAL NOT NULL DEFAULT 0,
            scrapRecovery REAL NOT NULL DEFAULT 0,
            totalCost REAL NOT NULL DEFAULT 0,
            actualUnitCost REAL NOT NULL DEFAULT 0,
            estimatedCost REAL NOT NULL DEFAULT 0,
            estimatedUnitCost REAL NOT NULL DEFAULT 0,
            status TEXT NOT NULL CHECK(status IN ('DRAFT', 'CALCULATED', 'FINALIZED')) DEFAULT 'DRAFT',
            calculatedAt INTEGER,
            finalizedAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (productId) REFERENCES products(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_costing_overhead_active ON costing_overhead_rules(active, base)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_costing_batch_order ON production_batch_costs(productionOrderId, status)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_costing_batch_product ON production_batch_costs(productId, finalizedAt DESC)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_costing_other_order ON production_other_costs(productionOrderId, date DESC)',
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-COSTING_VIEW', 'COSTING_VIEW', 'Costing', 'VIEW')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-COSTING_MANAGE', 'COSTING_MANAGE', 'Costing', 'MANAGE')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-COSTING_CALCULATE', 'COSTING_CALCULATE', 'Costing', 'CALCULATE')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-COSTING_FINALIZE', 'COSTING_FINALIZE', 'Costing', 'FINALIZE')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-COSTING_MARGIN_VIEW', 'COSTING_MARGIN_VIEW', 'Costing', 'VIEW_MARGIN')",
        );
        await db.rawInsert(
          "INSERT OR IGNORE INTO role_permissions (roleId, permissionId) SELECT 'role-system-admin', id FROM permissions WHERE code IN ('COSTING_VIEW', 'COSTING_MANAGE', 'COSTING_CALCULATE', 'COSTING_FINALIZE', 'COSTING_MARGIN_VIEW')",
        );
        await db.execute('PRAGMA user_version = 18');
        break;
      case 19:
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-BACKUP_VIEW', 'BACKUP_VIEW', 'BackupRestore', 'VIEW')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-BACKUP_CREATE', 'BACKUP_CREATE', 'BackupRestore', 'CREATE')",
        );
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-BACKUP_RESTORE', 'BACKUP_RESTORE', 'BackupRestore', 'RESTORE')",
        );
        await db.rawInsert(
          "INSERT OR IGNORE INTO role_permissions (roleId, permissionId) SELECT 'role-system-admin', id FROM permissions WHERE code IN ('BACKUP_VIEW', 'BACKUP_CREATE', 'BACKUP_RESTORE')",
        );
        await db.execute('PRAGMA user_version = 19');
        break;
      case 20:
        final duplicates = await db.rawQuery('''
          SELECT productId, COUNT(*) AS count
          FROM product_dimensions
          WHERE variantId IS NULL
          GROUP BY productId
          HAVING COUNT(*) > 1
        ''');
        if (duplicates.isNotEmpty) {
          throw StateError(
            'Duplicate product-level dimensions require manual review before migration',
          );
        }
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_dimensions_product_level ON product_dimensions(productId) WHERE variantId IS NULL',
        );
        await db.execute('PRAGMA user_version = 20');
        break;
      case 21:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_order_bom_items (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            rawMaterialId TEXT NOT NULL,
            unitId TEXT NOT NULL,
            quantity REAL NOT NULL CHECK(quantity > 0),
            notes TEXT,
            UNIQUE(productionOrderId, rawMaterialId),
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (rawMaterialId) REFERENCES raw_materials(id) ON DELETE RESTRICT,
            FOREIGN KEY (unitId) REFERENCES units(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_order_bom_items_order ON production_order_bom_items(productionOrderId)',
        );
        await db.execute('''
          CREATE TABLE IF NOT EXISTS production_order_labor_allocations (
            id TEXT PRIMARY KEY,
            productionOrderId TEXT NOT NULL,
            attendanceId TEXT NOT NULL,
            regularHours REAL NOT NULL CHECK(regularHours >= 0),
            overtimeHours REAL NOT NULL CHECK(overtimeHours >= 0),
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (productionOrderId) REFERENCES production_orders(id) ON DELETE RESTRICT,
            FOREIGN KEY (attendanceId) REFERENCES attendance_records(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_labor_allocations_order ON production_order_labor_allocations(productionOrderId)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_labor_allocations_attendance ON production_order_labor_allocations(attendanceId)',
        );
        await db.execute('PRAGMA user_version = 21');
        break;
      case 22:
        await db.execute(
          "INSERT OR IGNORE INTO permissions (id, code, module, action) VALUES ('permission-SALES_EDIT', 'SALES_EDIT', 'Sales', 'EDIT')",
        );
        await db.rawInsert(
          "INSERT OR IGNORE INTO role_permissions (roleId, permissionId) SELECT 'role-system-admin', id FROM permissions WHERE code IN ('SALES_VIEW', 'SALES_EDIT', 'SALES_DELIVER')",
        );
        await db.execute('PRAGMA user_version = 22');
        break;
      case 23:
        await db.execute(
          'ALTER TABLE sales_deliveries ADD COLUMN requestKey TEXT',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_delivery_request_key ON sales_deliveries(requestKey) WHERE requestKey IS NOT NULL',
        );
        await db.execute('PRAGMA user_version = 23');
        break;
      case 24:
        await db.execute(
          'ALTER TABLE sales_return_items ADD COLUMN sourceDeliveryItemId TEXT',
        );
        await db.execute(
          'ALTER TABLE sales_delivery_items ADD COLUMN unitRevenue REAL NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE sales_delivery_items ADD COLUMN unitCogs REAL NOT NULL DEFAULT 0',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sales_return_source_line ON sales_return_items(sourceDeliveryItemId)',
        );
        await db.execute('PRAGMA user_version = 24');
        break;
      case 25:
        await db.execute(
          'ALTER TABLE pricing_lists ADD COLUMN isDefault INTEGER NOT NULL DEFAULT 0 CHECK(isDefault IN (0, 1))',
        );
        await db.execute(
          'ALTER TABLE price_lists ADD COLUMN isDefault INTEGER NOT NULL DEFAULT 0 CHECK(isDefault IN (0, 1))',
        );
        await db.execute(
          "UPDATE pricing_lists SET isDefault = 1 WHERE code = 'DEFAULT'",
        );
        await db.execute(
          "UPDATE price_lists SET isDefault = 1 WHERE code = 'DEFAULT'",
        );
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customer_price_list_assignments (
            customerId TEXT PRIMARY KEY,
            priceListId TEXT NOT NULL,
            assignedAt INTEGER NOT NULL,
            FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE RESTRICT,
            FOREIGN KEY (priceListId) REFERENCES pricing_lists(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          UPDATE product_prices
          SET active = 0
          WHERE active = 1 AND variantId IS NULL AND EXISTS (
            SELECT 1 FROM product_prices newer
            WHERE newer.active = 1 AND newer.variantId IS NULL
              AND newer.priceListId = product_prices.priceListId
              AND newer.productId = product_prices.productId
              AND (newer.updatedAt > product_prices.updatedAt OR
                (newer.updatedAt = product_prices.updatedAt AND newer.id > product_prices.id))
          )
        ''');
        await db.execute('''
          UPDATE customer_price_overrides
          SET active = 0
          WHERE active = 1 AND variantId IS NULL AND EXISTS (
            SELECT 1 FROM customer_price_overrides newer
            WHERE newer.active = 1 AND newer.variantId IS NULL
              AND newer.customerId = customer_price_overrides.customerId
              AND newer.productId = customer_price_overrides.productId
              AND (newer.updatedAt > customer_price_overrides.updatedAt OR
                (newer.updatedAt = customer_price_overrides.updatedAt AND newer.id > customer_price_overrides.id))
          )
        ''');
        await db.execute('''
          UPDATE price_tiers
          SET active = 0
          WHERE active = 1 AND variantId IS NULL AND EXISTS (
            SELECT 1 FROM price_tiers newer
            WHERE newer.active = 1 AND newer.variantId IS NULL
              AND newer.priceListId IS price_tiers.priceListId
              AND newer.productId = price_tiers.productId
              AND newer.minimumQuantity = price_tiers.minimumQuantity
              AND (newer.updatedAt > price_tiers.updatedAt OR
                (newer.updatedAt = price_tiers.updatedAt AND newer.id > price_tiers.id))
          )
        ''');
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_product_prices_active_base ON product_prices(priceListId, productId) WHERE active = 1 AND variantId IS NULL',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_overrides_active_base ON customer_price_overrides(customerId, productId) WHERE active = 1 AND variantId IS NULL',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_price_tiers_active_base ON price_tiers(priceListId, productId, minimumQuantity) WHERE active = 1 AND variantId IS NULL',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_pricing_one_default ON pricing_lists(isDefault) WHERE isDefault = 1',
        );
        await db.execute('PRAGMA user_version = 25');
        break;
      case 26:
        await db.execute(
          'ALTER TABLE customer_payments ADD COLUMN operationKey TEXT',
        );
        await db.execute(
          'ALTER TABLE supplier_payments ADD COLUMN operationKey TEXT',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_customer_payment_operation ON customer_payments(operationKey) WHERE operationKey IS NOT NULL',
        );
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_supplier_payment_operation ON supplier_payments(operationKey) WHERE operationKey IS NOT NULL',
        );
        await db.execute(
          'ALTER TABLE production_material_consumptions ADD COLUMN unitCost REAL NOT NULL DEFAULT 0 CHECK(unitCost >= 0)',
        );
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_setup_state (
            id INTEGER PRIMARY KEY CHECK(id = 1),
            completed INTEGER NOT NULL CHECK(completed IN (0, 1))
          )
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO app_setup_state(id, completed)
          SELECT 1, CASE WHEN EXISTS (
            SELECT 1 FROM users WHERE roleId = 'role-system-admin'
          ) THEN 1 ELSE 0 END
        ''');
        await db.execute('PRAGMA user_version = 26');
        break;
      case 27:
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_alternatives (
            id TEXT PRIMARY KEY,
            sourceProductId TEXT NOT NULL,
            targetProductId TEXT NOT NULL,
            priority INTEGER NOT NULL CHECK(priority > 0),
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            UNIQUE(sourceProductId, targetProductId),
            UNIQUE(sourceProductId, priority),
            CHECK(sourceProductId != targetProductId),
            FOREIGN KEY (sourceProductId) REFERENCES products(id) ON DELETE RESTRICT,
            FOREIGN KEY (targetProductId) REFERENCES products(id) ON DELETE RESTRICT
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_product_alternatives_target ON product_alternatives(targetProductId)',
        );
        await db.execute('PRAGMA user_version = 27');
        break;
      default:
        break;
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _database = null;
  }

  Future<void> resetForTesting() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    await close();

    _testDatabaseSequence++;
    _databaseFileName =
        'furnexa_test_${_testDatabaseSequence}_${DateTime.now().microsecondsSinceEpoch}.db';

    _testDatabaseDirectory = await getDatabasesPath();
    final path = join(_testDatabaseDirectory!, _databaseFileName);
    final file = File(path);
    if (file.existsSync()) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await deleteDatabase(path);
    }
  }
}
