import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/factory_structure/data/repositories/factory_structure_repository_impl.dart';
import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/factory_structure/domain/entities/workshop.dart';
import 'package:furnexa/features/production/data/datasources/production_local_data_source.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/raw_materials_products/data/repositories/raw_materials_products_repository_impl.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

class DemoSeedSummary {
  const DemoSeedSummary({required this.databasePath, required this.counts});

  final String databasePath;
  final Map<String, int> counts;
}

class DemoDataSeeder {
  DemoDataSeeder({
    FactoryStructureRepositoryImpl? factory,
    RawMaterialsProductsRepositoryImpl? catalog,
    PurchasingLocalDataSource? purchasing,
    ProductionLocalDataSource? production,
    SalesLocalDataSource? sales,
    AccountingLocalDataSource? accounting,
    SecurityLocalDataSource? security,
  }) : _factory = factory ?? FactoryStructureRepositoryImpl(),
       _catalog = catalog ?? RawMaterialsProductsRepositoryImpl(),
       _purchasing = purchasing ?? PurchasingLocalDataSource(),
       _production = production ?? ProductionLocalDataSource(),
       _sales = sales ?? SalesLocalDataSource(),
       _accounting = accounting ?? AccountingLocalDataSource(),
       _security = security ?? SecurityLocalDataSource();

  static const factoryId = 'DEMO-FACTORY-01';
  static const rawWarehouseId = 'DEMO-WH-RAW-01';
  static const wipWarehouseId = 'DEMO-WH-WIP-01';
  static const finishedWarehouseId = 'DEMO-WH-FINISHED-01';
  static const quarantineWarehouseId = 'DEMO-WH-QUARANTINE-01';
  static const piecesUnitId = 'DEMO-UNIT-PCS';
  static const meterUnitId = 'DEMO-UNIT-M';
  static const kilogramUnitId = 'DEMO-UNIT-KG';
  static const categoryId = 'DEMO-CATEGORY-FURNITURE';
  static const sofaId = 'DEMO-PRODUCT-SOFA';
  static const tableId = 'DEMO-PRODUCT-TABLE';
  static const chairId = 'DEMO-PRODUCT-CHAIR';
  static const sofaGrayVariantId = 'DEMO-VARIANT-SOFA-GRAY';
  static const sofaSandVariantId = 'DEMO-VARIANT-SOFA-SAND';
  static const timberId = 'DEMO-MATERIAL-TIMBER';
  static const foamId = 'DEMO-MATERIAL-FOAM';
  static const fabricId = 'DEMO-MATERIAL-FABRIC';
  static const hardwareId = 'DEMO-MATERIAL-HARDWARE';
  static const supplierOneId = 'DEMO-SUPPLIER-01';
  static const supplierTwoId = 'DEMO-SUPPLIER-02';
  static const customerOneId = 'DEMO-CUSTOMER-01';
  static const customerTwoId = 'DEMO-CUSTOMER-02';
  static const customerThreeId = 'DEMO-CUSTOMER-03';
  static const rawPurchaseOrderId = 'DEMO-PO-RAW-01';
  static const finishedPurchaseOrderId = 'DEMO-PO-FINISHED-01';
  static const salesOrderOneId = 'DEMO-SO-001';
  static const salesOrderTwoId = 'DEMO-SO-002';
  static const salesOrderThreeId = 'DEMO-SO-003';

  final FactoryStructureRepositoryImpl _factory;
  final RawMaterialsProductsRepositoryImpl _catalog;
  final PurchasingLocalDataSource _purchasing;
  final ProductionLocalDataSource _production;
  final SalesLocalDataSource _sales;
  final AccountingLocalDataSource _accounting;
  final SecurityLocalDataSource _security;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<DemoSeedSummary> seed() async {
    if (_security.session?.isSystemAdmin != true) {
      throw StateError('Sign in as the System Administrator before seeding.');
    }
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_seed_manifest (
        seedKey TEXT PRIMARY KEY,
        seedValue TEXT NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    final now = DateTime(2026, 11, 1);

    await _seedFactoryStructure(now);
    await _seedCatalog(now);
    await _seedSuppliersAndPurchases(now);
    await _seedProduction(now);
    await _seedCustomersAndSales(now);
    await _seedHistoricalSales();
    await _seedAccounting(now);
    await _writeManifest('DEMO_FURNEXA_V1', 'complete');

    final counts = <String, int>{
      for (final table in const [
        'factories',
        'sections',
        'workshops',
        'production_stages',
        'warehouses',
        'categories',
        'units',
        'raw_materials',
        'products',
        'product_variants',
        'product_bom_items',
        'suppliers',
        'purchase_orders',
        'purchase_receipts',
        'customers',
        'sales_orders',
        'sales_deliveries',
        'sales_invoices',
        'production_orders',
        'production_material_consumptions',
        'production_outputs',
      ])
        table: await _demoCount(table),
    };
    return DemoSeedSummary(
      databasePath: await FurnexaDatabase.instance.databasePath,
      counts: counts,
    );
  }

  Future<void> _seedFactoryStructure(DateTime now) async {
    if (!await _exists('factories', factoryId)) {
      await _factory.saveFactory(
        FactoryProfile(
          id: factoryId,
          name: 'مصنع الأفق للأثاث',
          code: 'DEMO-FAB-01',
          phone: '+20 2 5550 2100',
          email: 'demo@example.invalid',
          address: 'مدينة العبور، القاهرة',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    for (final section in [
      Section(
        id: 'DEMO-SECTION-WOOD',
        factoryId: factoryId,
        name: 'قسم النجارة',
        code: 'DEMO-SEC-WOOD',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Section(
        id: 'DEMO-SECTION-UPHOLSTERY',
        factoryId: factoryId,
        name: 'قسم التنجيد',
        code: 'DEMO-SEC-UPH',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Section(
        id: 'DEMO-SECTION-FINISH',
        factoryId: factoryId,
        name: 'قسم التشطيب',
        code: 'DEMO-SEC-FIN',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('sections', section.id)) {
        await _factory.saveSection(section);
      }
    }
    for (final workshop in [
      Workshop(
        id: 'DEMO-WORKSHOP-CARPENTRY',
        factoryId: factoryId,
        sectionId: 'DEMO-SECTION-WOOD',
        name: 'ورشة التجميع الخشبي',
        code: 'DEMO-WS-WOOD',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Workshop(
        id: 'DEMO-WORKSHOP-UPHOLSTERY',
        factoryId: factoryId,
        sectionId: 'DEMO-SECTION-UPHOLSTERY',
        name: 'ورشة التنجيد',
        code: 'DEMO-WS-UPH',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('workshops', workshop.id)) {
        await _factory.saveWorkshop(workshop);
      }
    }
    for (final stage in [
      ProductionStage(
        id: 'DEMO-STAGE-CUT',
        factoryId: factoryId,
        name: 'قص وتجهيز',
        code: 'DEMO-ST-CUT',
        sequence: 1,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      ProductionStage(
        id: 'DEMO-STAGE-ASSEMBLY',
        factoryId: factoryId,
        name: 'تجميع',
        code: 'DEMO-ST-ASSEMBLY',
        sequence: 2,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      ProductionStage(
        id: 'DEMO-STAGE-FINISH',
        factoryId: factoryId,
        name: 'تشطيب وفحص',
        code: 'DEMO-ST-FINISH',
        sequence: 3,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('production_stages', stage.id)) {
        await _factory.saveProductionStage(stage);
      }
    }
    for (final warehouse in [
      Warehouse(
        id: rawWarehouseId,
        factoryId: factoryId,
        name: 'مخزن الخامات التجريبي',
        code: 'DEMO-WH-RAW',
        type: 'RAW_MATERIALS',
        purpose: WarehousePurpose.sellable,
        createdAt: now,
        updatedAt: now,
      ),
      Warehouse(
        id: wipWarehouseId,
        factoryId: factoryId,
        name: 'مخزن تحت التشغيل التجريبي',
        code: 'DEMO-WH-WIP',
        type: 'WORK_IN_PROGRESS',
        purpose: WarehousePurpose.rework,
        createdAt: now,
        updatedAt: now,
      ),
      Warehouse(
        id: finishedWarehouseId,
        factoryId: factoryId,
        name: 'مخزن المنتج التام التجريبي',
        code: 'DEMO-WH-FG',
        type: 'FINISHED_GOODS',
        purpose: WarehousePurpose.sellable,
        createdAt: now,
        updatedAt: now,
      ),
      Warehouse(
        id: quarantineWarehouseId,
        factoryId: factoryId,
        name: 'مخزن العزل التجريبي',
        code: 'DEMO-WH-QA',
        type: 'QUALITY_HOLD',
        purpose: WarehousePurpose.quarantine,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('warehouses', warehouse.id)) {
        await _factory.saveWarehouse(warehouse);
      }
    }
  }

  Future<void> _seedCatalog(DateTime now) async {
    if (!await _exists('categories', categoryId)) {
      await _catalog.saveCategory(
        Category(
          id: categoryId,
          name: 'أثاث منزلي تجريبي',
          code: 'DEMO-CAT-HOME',
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    for (final unit in [
      UnitEntity(
        id: piecesUnitId,
        name: 'قطعة',
        abbreviation: 'قطعة',
        createdAt: now,
        updatedAt: now,
      ),
      UnitEntity(
        id: meterUnitId,
        name: 'متر',
        abbreviation: 'م',
        createdAt: now,
        updatedAt: now,
      ),
      UnitEntity(
        id: kilogramUnitId,
        name: 'كيلوجرام',
        abbreviation: 'كجم',
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('units', unit.id)) await _catalog.saveUnit(unit);
    }
    for (final color in [
      ItemColor(
        id: 'DEMO-COLOR-GRAY',
        name: 'رمادي',
        code: 'DEMO-COL-GRAY',
        createdAt: now,
        updatedAt: now,
      ),
      ItemColor(
        id: 'DEMO-COLOR-SAND',
        name: 'رملي',
        code: 'DEMO-COL-SAND',
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('colors', color.id)) await _catalog.saveColor(color);
    }
    for (final material in [
      RawMaterial(
        id: timberId,
        name: 'خشب زان مجفف',
        code: 'DEMO-RM-BEECH',
        categoryId: categoryId,
        unitId: meterUnitId,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      RawMaterial(
        id: foamId,
        name: 'إسفنج كثافة ٣٣',
        code: 'DEMO-RM-FOAM33',
        categoryId: categoryId,
        unitId: kilogramUnitId,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      RawMaterial(
        id: fabricId,
        name: 'قماش تنجيد قطني',
        code: 'DEMO-RM-FABRIC',
        categoryId: categoryId,
        unitId: meterUnitId,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      RawMaterial(
        id: hardwareId,
        name: 'طقم مسامير ومفصلات',
        code: 'DEMO-RM-HARDWARE',
        categoryId: categoryId,
        unitId: piecesUnitId,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('raw_materials', material.id)) {
        await _catalog.saveRawMaterial(material);
      }
    }
    for (final product in [
      Product(
        id: sofaId,
        name: 'أريكة النيل ثلاثية',
        code: 'DEMO-FG-SOFA-3',
        categoryId: categoryId,
        unitId: piecesUnitId,
        state: ProductState.finished,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: tableId,
        name: 'طاولة سفرة خشب زان',
        code: 'DEMO-FG-TABLE-6',
        categoryId: categoryId,
        unitId: piecesUnitId,
        state: ProductState.finished,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Product(
        id: chairId,
        name: 'كرسي جانبي مبطن',
        code: 'DEMO-FG-CHAIR',
        categoryId: categoryId,
        unitId: piecesUnitId,
        state: ProductState.finished,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('products', product.id)) {
        await _catalog.saveProduct(product);
      }
    }
    for (final variant in [
      ProductVariant(
        id: sofaGrayVariantId,
        productId: sofaId,
        name: 'رمادي فاتح',
        code: 'DEMO-SOFA-GRAY',
        colorId: 'DEMO-COLOR-GRAY',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      ProductVariant(
        id: sofaSandVariantId,
        productId: sofaId,
        name: 'رملي',
        code: 'DEMO-SOFA-SAND',
        colorId: 'DEMO-COLOR-SAND',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('product_variants', variant.id)) {
        await _catalog.saveVariant(variant);
      }
    }
    for (final bom in [
      BomItem(
        id: 'DEMO-BOM-SOFA-TIMBER',
        productId: sofaId,
        rawMaterialId: timberId,
        quantity: 4,
        notes: 'إطار الأريكة',
      ),
      BomItem(
        id: 'DEMO-BOM-SOFA-FOAM',
        productId: sofaId,
        rawMaterialId: foamId,
        quantity: 2,
        notes: 'حشوة المقاعد',
      ),
      BomItem(
        id: 'DEMO-BOM-SOFA-FABRIC',
        productId: sofaId,
        rawMaterialId: fabricId,
        quantity: 3,
        notes: 'كسوة الأريكة',
      ),
      BomItem(
        id: 'DEMO-BOM-TABLE-TIMBER',
        productId: tableId,
        rawMaterialId: timberId,
        quantity: 5,
        notes: 'سطح وأرجل الطاولة',
      ),
      BomItem(
        id: 'DEMO-BOM-TABLE-HARDWARE',
        productId: tableId,
        rawMaterialId: hardwareId,
        quantity: 8,
        notes: 'تثبيت الطاولة',
      ),
    ]) {
      if (!await _exists('product_bom_items', bom.id)) {
        await _catalog.saveBomItem(bom);
      }
    }
  }

  Future<void> _seedSuppliersAndPurchases(DateTime now) async {
    for (final supplier in [
      Supplier(
        id: supplierOneId,
        name: 'مورد النخبة للأخشاب',
        code: 'DEMO-SUP-WOOD',
        phone: '+20 2 5550 3101',
        address: 'دمياط، مصر',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Supplier(
        id: supplierTwoId,
        name: 'مورد الراية للخامات الجاهزة',
        code: 'DEMO-SUP-FIN',
        phone: '+20 2 5550 3102',
        address: 'القاهرة، مصر',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      if (!await _exists('suppliers', supplier.id)) {
        await _purchasing.saveSupplier(supplier);
      }
    }
    final rawOrder = await _ensurePurchaseOrder(
      id: rawPurchaseOrderId,
      number: 'DEMO-PO-RAW-001',
      supplierId: supplierOneId,
      now: now,
      items: [
        _purchaseItem(
          'DEMO-PO-RAW-L1',
          timberId,
          PurchasingItemType.rawMaterial,
          meterUnitId,
          120,
          420,
        ),
        _purchaseItem(
          'DEMO-PO-RAW-L2',
          foamId,
          PurchasingItemType.rawMaterial,
          kilogramUnitId,
          80,
          95,
        ),
        _purchaseItem(
          'DEMO-PO-RAW-L3',
          fabricId,
          PurchasingItemType.rawMaterial,
          meterUnitId,
          100,
          180,
        ),
        _purchaseItem(
          'DEMO-PO-RAW-L4',
          hardwareId,
          PurchasingItemType.rawMaterial,
          piecesUnitId,
          200,
          12,
        ),
      ],
    );
    await _ensureReceipt(rawOrder, rawWarehouseId, 'DEMO-RECEIPT-RAW-001', now);
    final finishedOrder = await _ensurePurchaseOrder(
      id: finishedPurchaseOrderId,
      number: 'DEMO-PO-FIN-001',
      supplierId: supplierTwoId,
      now: now,
      items: [
        _purchaseItem(
          'DEMO-PO-FIN-L1',
          sofaId,
          PurchasingItemType.product,
          piecesUnitId,
          10,
          18000,
          variantId: sofaGrayVariantId,
          identityKind: 'VARIANT',
        ),
        _purchaseItem(
          'DEMO-PO-FIN-L2',
          tableId,
          PurchasingItemType.product,
          piecesUnitId,
          8,
          12000,
        ),
        _purchaseItem(
          'DEMO-PO-FIN-L3',
          chairId,
          PurchasingItemType.product,
          piecesUnitId,
          20,
          3800,
        ),
      ],
    );
    await _ensureReceipt(
      finishedOrder,
      finishedWarehouseId,
      'DEMO-RECEIPT-FIN-001',
      now,
    );
  }

  PurchasingItem _purchaseItem(
    String id,
    String itemId,
    PurchasingItemType type,
    String unitId,
    double quantity,
    double unitPrice, {
    String? variantId,
    String identityKind = 'BASE',
  }) => PurchasingItem(
    id: id,
    itemId: itemId,
    itemType: type,
    quantity: quantity,
    unitId: unitId,
    baseUnitId: unitId,
    variantId: variantId,
    unitConversionFactor: 1,
    baseQuantity: quantity,
    inventoryIdentityKind: identityKind,
    unitPrice: unitPrice,
    lineTotal: quantity * unitPrice,
  );

  Future<PurchaseOrder> _ensurePurchaseOrder({
    required String id,
    required String number,
    required String supplierId,
    required DateTime now,
    required List<PurchasingItem> items,
  }) async {
    final existing = await (await _db).query(
      'purchase_orders',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.quantity * item.unitPrice,
      );
      await _purchasing.saveOrder(
        PurchaseOrder(
          id: id,
          orderNumber: number,
          supplierId: supplierId,
          orderDate: now,
          expectedDeliveryDate: now.add(const Duration(days: 14)),
          status: PurchaseOrderStatus.draft,
          subtotal: subtotal,
          discount: 0,
          tax: 0,
          grandTotal: subtotal,
          notes: 'DEMO: seed purchase order',
          createdAt: now,
          updatedAt: now,
          items: items,
        ),
      );
      await _purchasing.changeOrderStatus(id, PurchaseOrderStatus.approved);
    }
    final order = (await _purchasing.orders()).singleWhere(
      (value) => value.id == id,
    );
    if (order.status == PurchaseOrderStatus.draft) {
      await _purchasing.changeOrderStatus(id, PurchaseOrderStatus.approved);
      return (await _purchasing.orders()).singleWhere(
        (value) => value.id == id,
      );
    }
    return order;
  }

  Future<void> _ensureReceipt(
    PurchaseOrder order,
    String warehouseId,
    String operationId,
    DateTime now,
  ) async {
    final db = await _db;
    for (final item in order.items) {
      final lineOperationId = '$operationId-${item.id}';
      final receiptNumber = 'GR-OP-$lineOperationId';
      final existing = await db.query(
        'purchase_receipts',
        columns: ['id'],
        where: 'receiptNumber = ?',
        whereArgs: [receiptNumber],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await _purchasing.postReceipt(
        order: order,
        warehouseId: warehouseId,
        receiptDate: now,
        items: [item],
        operationId: lineOperationId,
        notes: 'DEMO: supplier receipt',
      );
    }
  }

  Future<void> _seedProduction(DateTime now) async {
    for (final productId in [sofaId, tableId]) {
      final route = await _production.routeForProduct(productId);
      if (route == null) {
        await _production.saveRoute(productId, const [
          'DEMO-STAGE-CUT',
          'DEMO-STAGE-ASSEMBLY',
          'DEMO-STAGE-FINISH',
        ]);
      }
      if (await _production.routeForProduct(productId) == null) {
        throw StateError(
          'The demo production route for $productId was not saved.',
        );
      }
    }
    final completedId = await _ensureProductionOrderId(
      manifestKey: 'production-complete-id',
      note: 'DEMO: completed sofa batch',
      plannedQuantity: 2,
      variantId: sofaGrayVariantId,
    );
    await _completeDemoProduction(completedId, now);

    final inProgressId = await _ensureProductionOrderId(
      manifestKey: 'production-progress-id',
      note: 'DEMO: active sofa batch',
      plannedQuantity: 3,
      variantId: sofaGrayVariantId,
    );
    var inProgress = await _production.getOrder(inProgressId);
    if (inProgress.status == ProductionOrderStatus.draft) {
      await _production.planOrder(inProgressId);
      inProgress = await _production.getOrder(inProgressId);
    }
    if (inProgress.status == ProductionOrderStatus.planned) {
      await _production.startOrder(inProgressId);
      inProgress = await _production.getOrder(inProgressId);
    }
    if (inProgress.status == ProductionOrderStatus.inProgress &&
        inProgress.stages.isNotEmpty &&
        inProgress.stages.first.status == ProductionStageStatus.pending) {
      await _production.startStage(inProgress.stages.first.id);
    }
    final hasConsumption = await (await _db).query(
      'production_material_consumptions',
      where: 'productionOrderId = ?',
      whereArgs: [inProgressId],
      limit: 1,
    );
    if (hasConsumption.isEmpty) {
      for (final material in [
        (timberId, 4.0),
        (foamId, 2.0),
        (fabricId, 3.0),
      ]) {
        await _production.consumeMaterial(
          orderId: inProgressId,
          rawMaterialId: material.$1,
          warehouseId: rawWarehouseId,
          quantity: material.$2,
          date: now,
          operationId: 'DEMO-CONSUME-PROGRESS-${material.$1}',
          notes: 'DEMO: partial production consumption',
        );
      }
    }

    final plannedId = await _ensureProductionOrderId(
      manifestKey: 'production-planned-id',
      note: 'DEMO: planned table batch',
      plannedQuantity: 2,
      productId: tableId,
    );
    final planned = await _production.getOrder(plannedId);
    if (planned.status == ProductionOrderStatus.draft) {
      await _production.planOrder(plannedId);
    }
  }

  Future<String> _ensureProductionOrderId({
    required String manifestKey,
    required String note,
    required double plannedQuantity,
    String? variantId,
    String productId = sofaId,
  }) async {
    final mapped = await _manifestValue(manifestKey);
    if (mapped != null && await _exists('production_orders', mapped)) {
      return mapped;
    }
    final rows = await (await _db).query(
      'production_orders',
      columns: ['id'],
      where: 'notes = ?',
      whereArgs: [note],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final id = rows.single['id'] as String;
      await _writeManifest(manifestKey, id);
      return id;
    }
    final order = await _production.createOrder(
      productId: productId,
      variantId: variantId,
      expectedUnitId: piecesUnitId,
      plannedQuantity: plannedQuantity,
      notes: note,
    );
    await _writeManifest(manifestKey, order.id);
    return order.id;
  }

  Future<void> _completeDemoProduction(String orderId, DateTime now) async {
    var order = await _production.getOrder(orderId);
    if (order.status == ProductionOrderStatus.completed) return;
    if (order.status == ProductionOrderStatus.draft) {
      await _production.planOrder(orderId);
      order = await _production.getOrder(orderId);
    }
    if (order.status == ProductionOrderStatus.planned) {
      await _production.startOrder(orderId);
      order = await _production.getOrder(orderId);
    }
    if (order.status != ProductionOrderStatus.inProgress) return;

    for (final material in [(timberId, 8.0), (foamId, 4.0), (fabricId, 6.0)]) {
      await _production.consumeMaterial(
        orderId: orderId,
        rawMaterialId: material.$1,
        warehouseId: rawWarehouseId,
        quantity: material.$2,
        date: now,
        operationId: 'DEMO-CONSUME-COMPLETE-${material.$1}',
        notes: 'DEMO: full sofa batch material issue',
      );
    }
    order = await _production.getOrder(orderId);
    for (final stage in order.stages) {
      if (stage.status == ProductionStageStatus.pending) {
        await _production.startStage(stage.id);
        await _production.completeStage(stage.id);
      } else if (stage.status == ProductionStageStatus.inProgress) {
        await _production.completeStage(stage.id);
      }
    }
    await _production.recordOutput(
      orderId: orderId,
      warehouseId: finishedWarehouseId,
      quantity: 2,
      date: now,
      operationId: 'DEMO-OUTPUT-SOFA-COMPLETE',
      notes: 'DEMO: two completed sofas',
    );
  }

  Future<void> _seedCustomersAndSales(DateTime now) async {
    for (final customer in [
      Customer(
        id: customerOneId,
        name: 'شركة بيت العائلة',
        code: 'DEMO-CUST-001',
        phone: '+20 100 555 0101',
        address: 'مدينة نصر، القاهرة',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Customer(
        id: customerTwoId,
        name: 'معرض لمسة عصرية',
        code: 'DEMO-CUST-002',
        phone: '+20 100 555 0102',
        address: 'الإسكندرية',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      Customer(
        id: customerThreeId,
        name: 'مكتب روافد للتصميم',
        code: 'DEMO-CUST-003',
        phone: '+20 100 555 0103',
        address: 'الجيزة',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]) {
      final row = await (await _db).query(
        'customers',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [customer.id],
        limit: 1,
      );
      if (row.isEmpty) await _sales.saveCustomer(customer);
    }

    final first = await _ensureSalesOrder(
      id: salesOrderOneId,
      number: 'DEMO-SO-001',
      customerId: customerOneId,
      now: now,
      status: SalesOrderStatus.confirmed,
      items: [
        SalesItem(
          id: 'DEMO-SO-001-SOFA',
          itemId: sofaId,
          itemType: SalesItemType.product,
          quantity: 2,
          unitId: piecesUnitId,
          variantId: sofaGrayVariantId,
          baseUnitId: piecesUnitId,
          baseQuantity: 2,
          inventoryIdentityKind: 'VARIANT',
          unitPrice: 32000,
          discount: 2000,
          lineTotal: 62000,
        ),
        SalesItem(
          id: 'DEMO-SO-001-TABLE',
          itemId: tableId,
          itemType: SalesItemType.product,
          quantity: 1,
          unitId: piecesUnitId,
          baseUnitId: piecesUnitId,
          baseQuantity: 1,
          unitPrice: 20000,
          lineTotal: 20000,
        ),
      ],
    );
    await _sales.issueInvoice(
      salesOrderId: first.id,
      invoiceDate: now,
      items: const [
        SalesInvoiceLineRequest(
          salesOrderItemId: 'DEMO-SO-001-SOFA',
          quantity: 1,
        ),
        SalesInvoiceLineRequest(
          salesOrderItemId: 'DEMO-SO-001-TABLE',
          quantity: 1,
        ),
      ],
      operationId: 'DEMO-INVOICE-001',
      invoiceDiscount: 1000,
    );
    await _completeDelivery(
      first,
      operationId: 'DEMO-DELIVERY-COMPLETE-001',
      item: SalesItem(
        id: 'DEMO-SO-001-SOFA',
        itemId: sofaId,
        itemType: SalesItemType.product,
        quantity: 1,
        unitId: piecesUnitId,
        variantId: sofaGrayVariantId,
        baseUnitId: piecesUnitId,
        baseQuantity: 1,
        inventoryIdentityKind: 'VARIANT',
      ),
      now: now,
    );

    final second = await _ensureSalesOrder(
      id: salesOrderTwoId,
      number: 'DEMO-SO-002',
      customerId: customerTwoId,
      now: now,
      status: SalesOrderStatus.confirmed,
      items: [
        SalesItem(
          id: 'DEMO-SO-002-CHAIR',
          itemId: chairId,
          itemType: SalesItemType.product,
          quantity: 4,
          unitId: piecesUnitId,
          baseUnitId: piecesUnitId,
          baseQuantity: 4,
          unitPrice: 12500,
          lineTotal: 50000,
        ),
      ],
    );
    await _ensurePendingDelivery(
      second,
      operationId: 'DEMO-DELIVERY-PENDING-002',
      item: SalesItem(
        id: 'DEMO-SO-002-CHAIR',
        itemId: chairId,
        itemType: SalesItemType.product,
        quantity: 2,
        unitId: piecesUnitId,
        baseUnitId: piecesUnitId,
        baseQuantity: 2,
      ),
      now: now,
    );

    await _ensureSalesOrder(
      id: salesOrderThreeId,
      number: 'DEMO-SO-003',
      customerId: customerThreeId,
      now: now,
      status: SalesOrderStatus.draft,
      items: [
        SalesItem(
          id: 'DEMO-SO-003-SOFA',
          itemId: sofaId,
          itemType: SalesItemType.product,
          quantity: 1,
          unitId: piecesUnitId,
          variantId: sofaSandVariantId,
          baseUnitId: piecesUnitId,
          baseQuantity: 1,
          inventoryIdentityKind: 'VARIANT',
          unitPrice: 34500,
          lineTotal: 34500,
        ),
        SalesItem(
          id: 'DEMO-SO-003-CHAIR',
          itemId: chairId,
          itemType: SalesItemType.product,
          quantity: 2,
          unitId: piecesUnitId,
          baseUnitId: piecesUnitId,
          baseQuantity: 2,
          unitPrice: 12500,
          discount: 500,
          lineTotal: 24500,
        ),
      ],
    );
  }

  Future<SalesOrder> _ensureSalesOrder({
    required String id,
    required String number,
    required String customerId,
    required DateTime now,
    required SalesOrderStatus status,
    required List<SalesItem> items,
  }) async {
    final existing = await (await _db).query(
      'sales_orders',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.quantity * item.unitPrice,
      );
      final discount = items.fold<double>(
        0,
        (sum, item) => sum + item.discount,
      );
      final tax = items.fold<double>(0, (sum, item) => sum + item.tax);
      await _sales.saveOrder(
        SalesOrder(
          id: id,
          orderNumber: number,
          customerId: customerId,
          orderDate: now,
          status: status,
          subtotal: subtotal,
          discount: discount,
          tax: tax,
          grandTotal: subtotal - discount + tax,
          notes: 'DEMO: sales price snapshot',
          createdAt: now,
          updatedAt: now,
          items: items,
        ),
      );
    }
    return (await _sales.orders()).singleWhere((value) => value.id == id);
  }

  Future<void> _ensurePendingDelivery(
    SalesOrder order, {
    required String operationId,
    required SalesItem item,
    required DateTime now,
  }) async {
    final existing = await (await _db).query(
      'sales_deliveries',
      columns: ['id'],
      where: 'operationId = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await _sales.postDelivery(
      order: order,
      warehouseId: finishedWarehouseId,
      deliveryDate: now,
      items: [item],
      operationId: operationId,
      notes: 'DEMO: pending delivery reservation',
    );
  }

  Future<void> _completeDelivery(
    SalesOrder order, {
    required String operationId,
    required SalesItem item,
    required DateTime now,
  }) async {
    final existing = await (await _db).query(
      'sales_deliveries',
      where: 'operationId = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    SalesDelivery delivery;
    if (existing.isEmpty) {
      delivery = await _sales.postDelivery(
        order: order,
        warehouseId: finishedWarehouseId,
        deliveryDate: now,
        items: [item],
        operationId: operationId,
        notes: 'DEMO: partial delivery',
      );
    } else {
      final rows = await _sales.deliveries(order.id);
      delivery = rows.singleWhere((value) => value.id == existing.single['id']);
    }
    if (delivery.status == DeliveryDispatchStatus.pending) {
      delivery = await _sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.dispatched,
        dispatchDate: now,
      );
    }
    if (delivery.status == DeliveryDispatchStatus.dispatched) {
      delivery = await _sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.inTransit,
      );
    }
    if (delivery.status == DeliveryDispatchStatus.inTransit) {
      await _sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.delivered,
      );
    }
  }

  Future<void> _seedAccounting(DateTime now) async {
    final db = await _db;
    final cashboxRows = await db.query(
      'cashboxes',
      columns: ['id'],
      where: 'code = ?',
      whereArgs: ['DEMO-CASH-01'],
      limit: 1,
    );
    final cashboxId = cashboxRows.isNotEmpty
        ? cashboxRows.single['id'] as String
        : (await _accounting.createCashbox(
            name: 'خزينة صالة العرض التجريبية',
            code: 'DEMO-CASH-01',
            accountId: 'system-1000',
            openingBalance: 0,
            notes: 'DEMO: sales and expense testing',
          )).id;
    final payments = await db.query(
      'customer_payments',
      columns: ['id'],
      where: 'operationKey = ?',
      whereArgs: ['CALLER:DEMO-CUSTOMER-PAYMENT-001'],
      limit: 1,
    );
    if (payments.isEmpty) {
      await _accounting.postCustomerPayment(
        customerId: customerOneId,
        date: now,
        amount: 5000,
        cashboxId: cashboxId,
        reference: 'DEMO-INVOICE-001',
        notes: 'دفعة جزئية تجريبية',
        operationId: 'DEMO-CUSTOMER-PAYMENT-001',
      );
    }
    final expenses = await db.query(
      'expenses',
      columns: ['id'],
      where: 'reference = ?',
      whereArgs: ['DEMO-EXPENSE-001'],
      limit: 1,
    );
    if (expenses.isEmpty) {
      await _accounting.postExpense(
        date: now,
        accountId: 'system-5900',
        amount: 750,
        description: 'مصروفات تشغيل صالة العرض التجريبية',
        cashboxId: cashboxId,
        reference: 'DEMO-EXPENSE-001',
      );
    }
  }

  Future<void> _seedHistoricalSales() async {
    const manifestKey = 'DEMO_HISTORICAL_SALES_V1';
    if (await _manifestValue(manifestKey) == 'complete') return;

    final db = await _db;
    final endNow = DateTime.now().toUtc();
    final periodEnd = DateTime.utc(endNow.year, endNow.month, endNow.day);
    final periodStart = periodEnd.subtract(const Duration(days: 364));
    final identities =
        <
          ({
            String productId,
            String? variantId,
            String unitId,
            String identityKind,
            double unitPrice,
            int phase,
          })
        >[
          (
            productId: sofaId,
            variantId: sofaGrayVariantId,
            unitId: piecesUnitId,
            identityKind: 'VARIANT',
            unitPrice: 32000,
            phase: 0,
          ),
          (
            productId: sofaId,
            variantId: sofaSandVariantId,
            unitId: piecesUnitId,
            identityKind: 'VARIANT',
            unitPrice: 34500,
            phase: 2,
          ),
          (
            productId: tableId,
            variantId: null,
            unitId: piecesUnitId,
            identityKind: 'BASE',
            unitPrice: 20000,
            phase: 4,
          ),
          (
            productId: chairId,
            variantId: null,
            unitId: piecesUnitId,
            identityKind: 'BASE',
            unitPrice: 12500,
            phase: 6,
          ),
        ];
    final dailyQuantities = <List<double>>[
      for (final identity in identities)
        List<double>.generate(
          365,
          (day) => (4 + ((day * 3 + identity.phase) % 9)).toDouble(),
        ),
    ];
    final orderItems = <SalesItem>[];
    var subtotal = 0.0;
    final stock = WarehousesStockLocalDataSource();
    for (var index = 0; index < identities.length; index++) {
      final identity = identities[index];
      final totalQuantity = dailyQuantities[index].fold<double>(
        0,
        (sum, quantity) => sum + quantity,
      );
      final productRows = await db.query(
        'products',
        columns: ['name', 'code'],
        where: 'id = ?',
        whereArgs: [identity.productId],
        limit: 1,
      );
      if (productRows.isEmpty) {
        throw StateError('Synthetic sales product is missing.');
      }
      final product = productRows.single;
      final itemId = 'DEMO-HISTORY-ITEM-${index + 1}';
      final identityKind = identity.identityKind == 'VARIANT'
          ? InventoryIdentityKind.variant
          : InventoryIdentityKind.base;
      orderItems.add(
        SalesItem(
          id: itemId,
          itemId: identity.productId,
          itemType: SalesItemType.product,
          quantity: totalQuantity,
          unitId: identity.unitId,
          variantId: identity.variantId,
          baseUnitId: identity.unitId,
          baseQuantity: totalQuantity,
          inventoryIdentityKind: identity.identityKind,
          identitySnapshotStatus: 'VERIFIED',
          unitPrice: identity.unitPrice,
          lineTotal: totalQuantity * identity.unitPrice,
        ),
      );
      subtotal += totalQuantity * identity.unitPrice;
      await stock.stockIn(
        warehouseId: finishedWarehouseId,
        item: StockItemOption(
          id: identity.productId,
          name: product['name'] as String,
          code: product['code'] as String,
          unitId: identity.unitId,
          type: StockItemType.product,
          active: true,
          productId: identity.productId,
          variantId: identity.variantId,
          identityKind: identityKind,
        ),
        quantity: totalQuantity + 100,
        date: periodStart.subtract(const Duration(days: 1)),
        reference: 'DEMO-HISTORY-STOCK-${index + 1}',
        notes: 'DEMO: synthetic forecasting history opening stock',
        operationId: 'DEMO-HISTORY-STOCK-${index + 1}',
      );
    }

    const orderId = 'DEMO-HISTORICAL-SALES-ORDER';
    final order = SalesOrder(
      id: orderId,
      orderNumber: 'DEMO-HISTORICAL-SALES-001',
      customerId: customerOneId,
      orderDate: periodStart,
      expectedDeliveryDate: periodEnd,
      status: SalesOrderStatus.confirmed,
      subtotal: subtotal,
      discount: 0,
      tax: 0,
      grandTotal: subtotal,
      notes: 'DEMO: synthetic daily demand history',
      createdAt: periodStart,
      updatedAt: periodStart,
      items: orderItems,
    );
    final existingOrder = await db.query(
      'sales_orders',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (existingOrder.isEmpty) await _sales.saveOrder(order);
    final persistedOrder = (await _sales.orders()).singleWhere(
      (value) => value.id == orderId,
    );

    for (var day = 0; day < 365; day++) {
      final deliveryDate = periodStart.add(Duration(days: day));
      final dailyItems = <SalesItem>[
        for (var index = 0; index < identities.length; index++)
          SalesItem(
            id: 'DEMO-HISTORY-ITEM-${index + 1}',
            itemId: identities[index].productId,
            itemType: SalesItemType.product,
            quantity: dailyQuantities[index][day],
            unitId: identities[index].unitId,
            variantId: identities[index].variantId,
            baseUnitId: identities[index].unitId,
            baseQuantity: dailyQuantities[index][day],
            inventoryIdentityKind: identities[index].identityKind,
            identitySnapshotStatus: 'VERIFIED',
          ),
      ];
      final operationId =
          'DEMO-HISTORY-DELIVERY-${deliveryDate.toIso8601String().substring(0, 10)}';
      final delivery = await _sales.postDelivery(
        order: persistedOrder,
        warehouseId: finishedWarehouseId,
        deliveryDate: deliveryDate,
        items: dailyItems,
        notes: 'DEMO: synthetic daily demand history',
        operationId: operationId,
      );
      await _sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.dispatched,
        dispatchDate: deliveryDate,
      );
      await _sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.inTransit,
      );
      await _sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.delivered,
      );
    }
    await _writeManifest(manifestKey, 'complete');
  }

  Future<bool> _exists(String table, String id) async =>
      (await (await _db).query(
        table,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).isNotEmpty;

  Future<int> _demoCount(String table) async {
    final rows = await (await _db).rawQuery(
      'SELECT COUNT(*) AS count FROM "$table"',
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<String?> _manifestValue(String key) async {
    final rows = await (await _db).query(
      'demo_seed_manifest',
      columns: ['seedValue'],
      where: 'seedKey = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['seedValue'] as String;
  }

  Future<void> _writeManifest(String key, String value) async {
    final db = await _db;
    final values = {
      'seedKey': key,
      'seedValue': value,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await db.insert(
      'demo_seed_manifest',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
