import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/data/repositories/purchasing_repository_impl.dart';
import 'package:furnexa/features/purchasing/presentation/pages/purchase_document_pages.dart';
import 'package:furnexa/features/purchasing/presentation/pages/purchasing_page.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'test_helpers/database_test_helper.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

void main() {
  late PurchasingLocalDataSource dataSource;
  late String suffix;
  late DateTime now;
  late String warehouseId;
  late String unitId;
  late String materialId;
  late String supplierId;

  Future<void> seed() async {
    final db = await FurnexaDatabase.instance.database;
    warehouseId = 'purchase-warehouse-$suffix';
    unitId = 'purchase-unit-$suffix';
    materialId = 'purchase-material-$suffix';
    supplierId = 'purchase-supplier-$suffix';
    final factoryId = 'purchase-factory-$suffix';
    final categoryId = 'purchase-category-$suffix';
    final timestamp = now.millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع مشتريات $suffix',
      'code': 'PF-$suffix',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مخزن مشتريات $suffix',
      'code': 'PW-$suffix',
      'state': 'active',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف مشتريات $suffix',
      'code': 'PC-$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة مشتريات $suffix',
      'abbreviation': 'PU$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('raw_materials', {
      'id': materialId,
      'name': 'خامة مشتريات $suffix',
      'code': 'PM-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('suppliers', {
      'id': supplierId,
      'name': 'مورد مشتريات $suffix',
      'code': 'PS-$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
  }

  Future<String> addMaterial(String key) async {
    final id = 'purchase-material-$suffix-$key';
    final timestamp = now.millisecondsSinceEpoch;
    await (await FurnexaDatabase.instance.database).insert('raw_materials', {
      'id': id,
      'name': 'خامة $key $suffix',
      'code': 'PM-$key-$suffix',
      'categoryId': 'purchase-category-$suffix',
      'unitId': unitId,
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    return id;
  }

  PurchaseRequest requestWithItems({
    required String id,
    required List<String> itemIds,
    List<double>? quantities,
    String? notes,
  }) => PurchaseRequest(
    id: id,
    requestNumber: 'PR-$id',
    requestDate: now,
    supplierId: supplierId,
    requestedBy: 'purchasing test',
    notes: notes,
    status: PurchaseRequestStatus.draft,
    createdAt: now,
    updatedAt: now,
    items: [
      for (var index = 0; index < itemIds.length; index++)
        PurchasingItem(
          id: purchasingDocumentItemId(id, index),
          itemId: itemIds[index],
          itemType: PurchasingItemType.rawMaterial,
          quantity: quantities?[index] ?? (index + 1).toDouble(),
          unitId: unitId,
        ),
    ],
  );

  PurchaseOrder orderWithLines({
    required String id,
    required List<String> itemIds,
    bool duplicateLineIds = false,
  }) {
    final lines = [
      for (var index = 0; index < itemIds.length; index++)
        PurchasingItem(
          id: duplicateLineIds
              ? '$id-duplicate-line'
              : purchasingDocumentItemId(id, index),
          itemId: itemIds[index],
          itemType: PurchasingItemType.rawMaterial,
          quantity: (index + 1).toDouble(),
          unitId: unitId,
          unitPrice: 2,
          lineTotal: (index + 1) * 2,
        ),
    ];
    final subtotal = lines.fold<double>(
      0,
      (total, line) => total + line.lineTotal,
    );
    return PurchaseOrder(
      id: id,
      orderNumber: 'PO-$id',
      supplierId: supplierId,
      orderDate: now,
      status: PurchaseOrderStatus.draft,
      subtotal: subtotal,
      discount: 0,
      tax: 0,
      grandTotal: subtotal,
      notes: 'order test',
      createdAt: now,
      updatedAt: now,
      items: lines,
    );
  }

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 9, 17);
    dataSource = PurchasingLocalDataSource();
    await seed();
  });

  testWidgets('purchase order supplier lookup ignores search filter', (
    tester,
  ) async {
    final secondMaterialId = await addMaterial('pdf-second');
    final order = orderWithLines(
      id: 'pdf-order-$suffix',
      itemIds: [materialId, secondMaterialId],
    );
    await dataSource.saveOrder(order);
    final repository = PurchasingRepositoryImpl(dataSource);
    expect(await repository.suppliers('no-supplier-match'), isEmpty);
    final supplier = await repository.supplierById(order.supplierId);
    expect(supplier?.name, 'مورد مشتريات $suffix');

    await tester.pumpWidget(const MaterialApp(home: PurchasingPage()));
    await tester.pumpAndSettle();
    final supplierSearch = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'بحث بالاسم أو الكود',
    );
    await tester.enterText(supplierSearch, 'no-supplier-match');
    await tester.pumpAndSettle();
    await tester.tap(find.text('أوامر الشراء').first);
    await tester.pumpAndSettle();
    expect(
      find.text('${order.orderNumber} • مورد مشتريات $suffix'),
      findsOneWidget,
    );
    expect(find.text(supplierId), findsNothing);
    await tester.tap(find.text(order.orderNumber));
    await tester.pumpAndSettle();

    expect(find.text('مورد مشتريات $suffix'), findsOneWidget);
    expect(find.text(supplierId), findsNothing);
    expect(find.text('خامة مشتريات $suffix'), findsOneWidget);
    expect(find.text('خامة pdf-second $suffix'), findsOneWidget);
    expect(find.text('الكود: PM-$suffix'), findsOneWidget);
    expect(find.text('الكود: PM-pdf-second-$suffix'), findsOneWidget);

    final bytes = await generatePurchaseDocumentPdf(
      factoryName: 'مصنع مشتريات $suffix',
      title: 'أمر شراء',
      number: order.orderNumber,
      date: order.orderDate,
      supplier: supplier,
      notes: order.notes,
      items: order.items,
      catalog: await dataSource.activeItems(),
      unitNames: {unitId: 'وحدة مشتريات $suffix'},
      showFinancials: true,
      subtotal: order.subtotal,
      discount: order.discount,
      tax: order.tax,
      grandTotal: order.grandTotal,
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
    expect(order.items.map((item) => item.itemId), [
      materialId,
      secondMaterialId,
    ]);
    expect(order.items.map((item) => item.quantity), [1, 2]);
    expect(order.items.map((item) => item.unitPrice), [2, 2]);
    expect(order.supplierId, supplierId);
    expect(supplier?.name, 'مورد مشتريات $suffix');
    expect(order.subtotal, 6);
    expect(order.discount, 0);
    expect(order.tax, 0);
    expect(order.grandTotal, 6);
  });

  test(
    'creates one request with three uniquely identified material lines',
    () async {
      final secondMaterial = await addMaterial('second');
      final thirdMaterial = await addMaterial('third');
      final request = requestWithItems(
        id: 'multi-request-$suffix',
        itemIds: [materialId, secondMaterial, thirdMaterial],
        quantities: [10, 5, 20],
      );

      await dataSource.saveRequest(request);

      final db = await FurnexaDatabase.instance.database;
      expect(
        await db.query(
          'purchase_requests',
          where: 'id = ?',
          whereArgs: [request.id],
        ),
        hasLength(1),
      );
      final rows = await db.query(
        'purchase_request_items',
        where: 'purchaseRequestId = ?',
        whereArgs: [request.id],
      );
      expect(rows, hasLength(3));
      expect(rows.map((row) => row['id']).toSet(), hasLength(3));
    },
  );

  test('reads supplier and all material line values back', () async {
    final secondMaterial = await addMaterial('read-second');
    final thirdMaterial = await addMaterial('read-third');
    final request = requestWithItems(
      id: 'read-request-$suffix',
      itemIds: [materialId, secondMaterial, thirdMaterial],
      quantities: [10, 5, 20],
    );
    await dataSource.saveRequest(request);

    final loaded = (await dataSource.requests()).single;
    expect(loaded.supplierId, supplierId);
    expect(loaded.items, hasLength(3));
    expect(loaded.items.map((item) => item.itemId).toSet(), {
      materialId,
      secondMaterial,
      thirdMaterial,
    });
    expect(loaded.items.map((item) => item.quantity), [10, 5, 20]);
    expect(loaded.items.map((item) => item.unitId), everyElement(unitId));
  });

  test(
    'request requires and persists its explicitly selected supplier',
    () async {
      final request = requestWithItems(
        id: 'supplier-required-$suffix',
        itemIds: [materialId],
      );
      final withoutSupplier = PurchaseRequest(
        id: request.id,
        requestNumber: request.requestNumber,
        requestDate: request.requestDate,
        supplierId: '',
        requestedBy: request.requestedBy,
        status: request.status,
        createdAt: request.createdAt,
        updatedAt: request.updatedAt,
        items: request.items,
      );

      await expectLater(
        dataSource.saveRequest(withoutSupplier),
        throwsException,
      );
      expect(
        await (await FurnexaDatabase.instance.database).query(
          'purchase_requests',
          where: 'id = ?',
          whereArgs: [request.id],
        ),
        isEmpty,
      );

      await dataSource.saveRequest(request);
      final row = (await (await FurnexaDatabase.instance.database).query(
        'purchase_requests',
        where: 'id = ?',
        whereArgs: [request.id],
      )).single;
      expect(row['supplierId'], supplierId);
    },
  );

  test(
    'saving the same request again replaces its lines without duplicates',
    () async {
      final secondMaterial = await addMaterial('resave-second');
      final thirdMaterial = await addMaterial('resave-third');
      final request = requestWithItems(
        id: 'resave-request-$suffix',
        itemIds: [materialId, secondMaterial, thirdMaterial],
      );
      await dataSource.saveRequest(request);

      await dataSource.saveRequest(request);

      final rows = await (await FurnexaDatabase.instance.database).query(
        'purchase_request_items',
        where: 'purchaseRequestId = ?',
        whereArgs: [request.id],
      );
      expect(rows, hasLength(3));
      expect(rows.map((row) => row['id']).toSet(), hasLength(3));
    },
  );

  test(
    'editing line quantity, adding, and removing lines saves the final set',
    () async {
      final secondMaterial = await addMaterial('edit-second');
      final thirdMaterial = await addMaterial('edit-third');
      final fourthMaterial = await addMaterial('edit-fourth');
      final request = requestWithItems(
        id: 'edit-request-$suffix',
        itemIds: [materialId, secondMaterial, thirdMaterial],
        quantities: [10, 5, 20],
      );
      await dataSource.saveRequest(request);
      final edited = requestWithItems(
        id: request.id,
        itemIds: [materialId, thirdMaterial, fourthMaterial],
        quantities: [12, 20, 1],
        notes: 'edited',
      );

      await dataSource.saveRequest(edited);

      final saved = (await dataSource.requests()).single;
      expect(saved.notes, 'edited');
      expect(saved.items, hasLength(3));
      expect(saved.items.map((item) => item.itemId).toSet(), {
        materialId,
        thirdMaterial,
        fourthMaterial,
      });
      expect(
        saved.items.singleWhere((item) => item.itemId == materialId).quantity,
        12,
      );
    },
  );

  test(
    'failed line replacement rolls back request and all existing lines',
    () async {
      final secondMaterial = await addMaterial('rollback-second');
      final request = requestWithItems(
        id: 'rollback-request-$suffix',
        itemIds: [materialId, secondMaterial],
        quantities: [10, 5],
        notes: 'original',
      );
      await dataSource.saveRequest(request);
      final invalidReplacement = PurchaseRequest(
        id: request.id,
        requestNumber: request.requestNumber,
        requestDate: request.requestDate,
        supplierId: request.supplierId,
        requestedBy: request.requestedBy,
        notes: 'must roll back',
        status: request.status,
        createdAt: request.createdAt,
        updatedAt: now,
        items: [
          PurchasingItem(
            id: 'duplicate-line-id-$suffix',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 99,
            unitId: unitId,
          ),
          PurchasingItem(
            id: 'duplicate-line-id-$suffix',
            itemId: secondMaterial,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 88,
            unitId: unitId,
          ),
        ],
      );

      await expectLater(
        dataSource.saveRequest(invalidReplacement),
        throwsException,
      );

      final saved = (await dataSource.requests()).single;
      expect(saved.notes, 'original');
      expect(saved.items, hasLength(2));
      expect(saved.items.map((item) => item.quantity).toSet(), {10.0, 5.0});
    },
  );

  test(
    'purchase order totals are recalculated and approval requires valid prices',
    () async {
      final purchaseOrder = PurchaseOrder(
        id: 'pricing-order-$suffix',
        orderNumber: 'PO-PRICING-$suffix',
        supplierId: supplierId,
        orderDate: now,
        status: PurchaseOrderStatus.draft,
        subtotal: 0,
        discount: 0,
        tax: 0,
        grandTotal: 0,
        createdAt: now,
        updatedAt: now,
        items: [
          PurchasingItem(
            id: 'pricing-order-item-$suffix',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 2,
            unitId: unitId,
            unitPrice: 0,
            discount: 0,
            tax: 0,
          ),
        ],
      );

      await dataSource.saveOrder(purchaseOrder);
      final savedDraft = (await dataSource.orders()).singleWhere(
        (value) => value.id == purchaseOrder.id,
      );
      await expectLater(
        dataSource.changeOrderStatus(
          savedDraft.id,
          PurchaseOrderStatus.approved,
        ),
        throwsException,
      );

      final pricedOrder = PurchaseOrder(
        id: purchaseOrder.id,
        orderNumber: purchaseOrder.orderNumber,
        supplierId: purchaseOrder.supplierId,
        orderDate: purchaseOrder.orderDate,
        status: PurchaseOrderStatus.draft,
        subtotal: 0,
        discount: 0,
        tax: 0,
        grandTotal: 0,
        createdAt: purchaseOrder.createdAt,
        updatedAt: purchaseOrder.updatedAt,
        items: [
          PurchasingItem(
            id: purchaseOrder.items.single.id,
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 2,
            unitId: unitId,
            unitPrice: 12,
            discount: 1,
            tax: 2,
          ),
        ],
      );

      await dataSource.saveOrder(pricedOrder);
      final saved = (await dataSource.orders()).singleWhere(
        (value) => value.id == pricedOrder.id,
      );
      expect(saved.subtotal, 24);
      expect(saved.discount, 1);
      expect(saved.tax, 2);
      expect(saved.grandTotal, 25);
      await expectLater(
        dataSource.changeOrderStatus(saved.id, PurchaseOrderStatus.approved),
        completes,
      );
      final approved = (await dataSource.orders()).singleWhere(
        (value) => value.id == saved.id,
      );
      expect(approved.status, PurchaseOrderStatus.approved);
    },
  );

  testWidgets(
    'request-converted order price lifecycle persists, approves, edits, and receives exact prices',
    (tester) async {
      final secondMaterial = await addMaterial('lifecycle-second');
      final repository = PurchasingRepositoryImpl(dataSource);
      final request = requestWithItems(
        id: 'price-lifecycle-$suffix',
        itemIds: [materialId, secondMaterial],
        quantities: [100, 30],
      );
      await repository.saveRequest(request);
      await dataSource.changeRequestStatus(
        request.id,
        PurchaseRequestStatus.pending,
      );
      final generated = await repository.approveRequest(request.id);
      expect(generated.status, PurchaseOrderStatus.draft);
      expect(generated.items.map((item) => item.unitPrice), [0, 0]);

      final db = await FurnexaDatabase.instance.database;
      final initialRows = await db.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [generated.id],
        orderBy: 'rowid ASC',
      );
      expect(initialRows.map((row) => row['unitPrice']), [0, 0]);

      Future<PurchaseOrder> editOrder(
        PurchaseOrder order, {
        required String firstPrice,
        String? secondPrice,
      }) async {
        final suppliers = await dataSource.suppliers();
        final catalog = await dataSource.activeItems();
        PurchaseOrder? edited;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    edited = await Navigator.of(context).push<PurchaseOrder>(
                      MaterialPageRoute(
                        builder: (_) => PurchaseOrderDocumentPage(
                          suppliers: suppliers,
                          items: catalog,
                          unitNames: {unitId: 'وحدة'},
                          createId: (prefix) => '$prefix-editor-$suffix',
                          createNumber: (prefix) => '$prefix-editor-$suffix',
                          initialOrder: order,
                        ),
                      ),
                    );
                  },
                  child: const Text('فتح المحرر'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('فتح المحرر'));
        await tester.pumpAndSettle();
        final priceFields = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'سعر الوحدة',
        );
        expect(priceFields, findsNWidgets(2));
        await tester.enterText(priceFields.at(0), firstPrice);
        if (secondPrice != null) {
          await tester.enterText(priceFields.at(1), secondPrice);
        }
        await tester.tap(find.text('حفظ المستند'));
        await tester.pumpAndSettle();
        expect(edited, isNotNull);
        return edited!;
      }

      final pricedDraft = await editOrder(
        generated,
        firstPrice: '25',
        secondPrice: '40',
      );
      expect(pricedDraft.supplierId, supplierId);
      expect(pricedDraft.items.map((item) => item.unitPrice), [25, 40]);
      final savedDraft = await repository.saveOrder(pricedDraft);
      expect(savedDraft.subtotal, 3700);
      expect(savedDraft.discount, 0);
      expect(savedDraft.tax, 0);
      expect(savedDraft.grandTotal, 3700);
      final invalidFinancials = pricedDraft.copyWith(
        items: [
          pricedDraft.items.first.copyWith(tax: double.nan),
          pricedDraft.items.last,
        ],
      );
      await expectLater(
        repository.saveOrder(invalidFinancials),
        throwsException,
      );

      var storedRows = await db.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [generated.id],
        orderBy: 'rowid ASC',
      );
      expect(storedRows.map((row) => row['unitPrice']), [25, 40]);
      expect(storedRows.map((row) => row['quantity']), [100, 30]);
      expect(storedRows.map((row) => row['lineTotal']), [2500, 1200]);
      expect(storedRows.map((row) => row['discount']), [0, 0]);
      expect(storedRows.map((row) => row['tax']), [0, 0]);
      expect(storedRows.map((row) => row['receivedQuantity']), [0, 0]);
      final savedHeader = (await db.query(
        'purchase_orders',
        where: 'id = ?',
        whereArgs: [generated.id],
      )).single;
      expect(savedHeader['subtotal'], 3700);
      expect(savedHeader['discount'], 0);
      expect(savedHeader['tax'], 0);
      expect(savedHeader['grandTotal'], 3700);

      var loaded = (await repository.orders()).singleWhere(
        (order) => order.id == generated.id,
      );
      expect(loaded.items.map((item) => item.unitPrice), [25, 40]);
      expect(loaded.items.map((item) => item.lineTotal), [2500, 1200]);
      expect(loaded.subtotal, 3700);
      expect(loaded.grandTotal, 3700);

      await repository.changeOrderStatus(
        loaded.id,
        PurchaseOrderStatus.approved,
      );
      loaded = (await repository.orders()).singleWhere(
        (order) => order.id == generated.id,
      );
      expect(loaded.status, PurchaseOrderStatus.approved);
      expect(loaded.items.map((item) => item.unitPrice), [25, 40]);
      expect(loaded.items.map((item) => item.lineTotal), [2500, 1200]);
      expect(loaded.grandTotal, 3700);
      storedRows = await db.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [generated.id],
        orderBy: 'rowid ASC',
      );
      expect(storedRows.map((row) => row['unitPrice']), [25, 40]);
      expect(storedRows.map((row) => row['lineTotal']), [2500, 1200]);

      final editedApproved = await editOrder(loaded, firstPrice: '27.5');
      expect(editedApproved.status, PurchaseOrderStatus.draft);
      final resaved = await repository.saveOrder(editedApproved);
      expect(resaved.items.map((item) => item.unitPrice), [27.5, 40]);
      expect(resaved.items.map((item) => item.lineTotal), [2750, 1200]);
      expect(resaved.subtotal, 3950);
      expect(resaved.grandTotal, 3950);

      storedRows = await db.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [generated.id],
        orderBy: 'rowid ASC',
      );
      expect(storedRows.map((row) => row['unitPrice']), [27.5, 40]);
      expect(storedRows.map((row) => row['lineTotal']), [2750, 1200]);
      final resavedHeader = (await db.query(
        'purchase_orders',
        where: 'id = ?',
        whereArgs: [generated.id],
      )).single;
      expect(resavedHeader['subtotal'], 3950);
      expect(resavedHeader['discount'], 0);
      expect(resavedHeader['tax'], 0);
      expect(resavedHeader['grandTotal'], 3950);
      loaded = (await repository.orders()).singleWhere(
        (order) => order.id == generated.id,
      );
      expect(loaded.items.map((item) => item.unitPrice), [27.5, 40]);
      expect(loaded.subtotal, 3950);
      expect(loaded.grandTotal, 3950);

      await repository.changeOrderStatus(
        loaded.id,
        PurchaseOrderStatus.approved,
      );
      loaded = (await repository.orders()).singleWhere(
        (order) => order.id == generated.id,
      );
      expect(loaded.status, PurchaseOrderStatus.approved);
      expect(loaded.items.map((item) => item.unitPrice), [27.5, 40]);
      expect(loaded.items.map((item) => item.lineTotal), [2750, 1200]);
      expect(loaded.grandTotal, 3950);
      storedRows = await db.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [generated.id],
        orderBy: 'rowid ASC',
      );
      expect(storedRows.map((row) => row['unitPrice']), [27.5, 40]);
      expect(storedRows.map((row) => row['lineTotal']), [2750, 1200]);

      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseDocumentDetailsPage(
            order: loaded,
            supplier: (await dataSource.suppliers()).single,
            items: await dataSource.activeItems(),
            unitNames: {unitId: 'وحدة'},
            onPrint: () async {},
          ),
        ),
      );
      expect(find.text('مورد مشتريات $suffix'), findsOneWidget);
      expect(find.text('خامة مشتريات $suffix'), findsOneWidget);
      expect(find.text('سعر الوحدة: 27.50'), findsOneWidget);
      expect(find.text('سعر الوحدة: 40.00'), findsOneWidget);
      expect(find.text('الإجمالي: 2750.00'), findsOneWidget);
      expect(find.text('الإجمالي: 1200.00'), findsOneWidget);
      expect(find.text('الإجمالي الكلي: 3950.00'), findsOneWidget);

      await repository.postReceipt(
        order: loaded,
        warehouseId: warehouseId,
        receiptDate: now,
        operationId: 'lifecycle-receipt-$suffix',
        items: [
          PurchasingItem(
            id: loaded.items.first.id,
            itemId: loaded.items.first.itemId,
            itemType: loaded.items.first.itemType,
            quantity: 5,
            unitId: loaded.items.first.unitId,
          ),
        ],
      );
      final receivedOrder = (await repository.orders()).singleWhere(
        (order) => order.id == generated.id,
      );
      expect(receivedOrder.items.map((item) => item.unitPrice), [27.5, 40]);
      expect(receivedOrder.items.first.receivedQuantity, 5);
      expect(receivedOrder.grandTotal, 3950);
      final receipt = (await dataSource.receipts(generated.id)).single;
      final accountingEntry = await AccountingRepositoryImpl()
          .journalEntryByReference(
            referenceType: 'PURCHASE_RECEIPT',
            referenceId: receipt.id,
          );
      expect(accountingEntry, isNotNull);
      expect(accountingEntry!.referenceId, receipt.id);
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseDocumentDetailsPage(
            order: receivedOrder,
            receipts: [receipt],
            receiptJournalEntries: {receipt.id: accountingEntry},
            supplier: (await dataSource.suppliers()).single,
            items: await dataSource.activeItems(),
            unitNames: {unitId: 'وحدة'},
            warehouses: [
              Warehouse(
                id: warehouseId,
                factoryId: 'purchase-factory-$suffix',
                name: 'مخزن مشتريات $suffix',
                code: 'PW-$suffix',
                createdAt: now,
                updatedAt: now,
              ),
            ],
            onPrint: () async {},
            onOpenAccountingEntry: (_) async {},
          ),
        ),
      );
      expect(find.text('عرض القيد المحاسبي'), findsOneWidget);
      expect(find.textContaining('مخزن مشتريات $suffix'), findsOneWidget);
      expect(find.textContaining(warehouseId), findsNothing);
    },
  );

  test(
    'purchase order saves and resaves multiple deterministic item rows',
    () async {
      final secondMaterial = await addMaterial('order-second');
      final thirdMaterial = await addMaterial('order-third');
      final purchaseOrder = orderWithLines(
        id: 'multi-order-$suffix',
        itemIds: [materialId, secondMaterial, thirdMaterial],
      );

      await dataSource.saveOrder(purchaseOrder);
      await dataSource.saveOrder(purchaseOrder);

      final saved = (await dataSource.orders()).single;
      expect(saved.items, hasLength(3));
      expect(saved.items.map((item) => item.id).toSet(), hasLength(3));
      expect(saved.items.map((item) => item.itemId).toSet(), {
        materialId,
        secondMaterial,
        thirdMaterial,
      });
      expect(
        await (await FurnexaDatabase.instance.database).query(
          'purchase_order_items',
          where: 'purchaseOrderId = ?',
          whereArgs: [purchaseOrder.id],
        ),
        hasLength(3),
      );
    },
  );

  test(
    'failed purchase order line insert rolls back header and earlier lines',
    () async {
      final secondMaterial = await addMaterial('order-rollback-second');
      final purchaseOrder = orderWithLines(
        id: 'rollback-order-$suffix',
        itemIds: [materialId, secondMaterial],
        duplicateLineIds: true,
      );

      await expectLater(dataSource.saveOrder(purchaseOrder), throwsException);

      final db = await FurnexaDatabase.instance.database;
      expect(
        await db.query(
          'purchase_orders',
          where: 'id = ?',
          whereArgs: [purchaseOrder.id],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'purchase_order_items',
          where: 'purchaseOrderId = ?',
          whereArgs: [purchaseOrder.id],
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Windows purchasing list scrollbars use their ListView controllers',
    (tester) async {
      await dataSource.saveRequest(
        PurchaseRequest(
          id: 'scroll-request-$suffix',
          requestNumber: 'PR-SCROLL-$suffix',
          requestDate: now,
          supplierId: supplierId,
          requestedBy: 'test',
          status: PurchaseRequestStatus.draft,
          createdAt: now,
          updatedAt: now,
          items: const [],
        ),
      );
      await dataSource.saveOrder(
        PurchaseOrder(
          id: 'scroll-order-$suffix',
          orderNumber: 'PO-SCROLL-$suffix',
          supplierId: supplierId,
          orderDate: now,
          status: PurchaseOrderStatus.draft,
          subtotal: 100,
          discount: 0,
          tax: 0,
          grandTotal: 100,
          createdAt: now,
          updatedAt: now,
          items: [
            PurchasingItem(
              id: 'scroll-order-item-$suffix',
              itemId: materialId,
              itemType: PurchasingItemType.rawMaterial,
              quantity: 100,
              unitId: unitId,
              unitPrice: 1,
              lineTotal: 100,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: const PurchasingPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tab in ['طلبات الشراء', 'أوامر الشراء', 'الموردين']) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  tearDown(() async {
    SecurityLocalDataSource().logout();
    await DatabaseTestHelper.reset();
  });

  PurchaseOrder order({
    required String id,
    PurchaseOrderStatus status = PurchaseOrderStatus.approved,
    double received = 0,
  }) => PurchaseOrder(
    id: id,
    orderNumber: 'PO-$id',
    supplierId: supplierId,
    orderDate: now,
    status: status,
    subtotal: 100,
    discount: 0,
    tax: 0,
    grandTotal: 100,
    createdAt: now,
    updatedAt: now,
    items: [
      PurchasingItem(
        id: '$id-item',
        itemId: materialId,
        itemType: PurchasingItemType.rawMaterial,
        quantity: 100,
        unitId: unitId,
        unitPrice: 1,
        receivedQuantity: received,
        lineTotal: 100,
      ),
    ],
  );

  test(
    'supplier create, update, uniqueness, and inactive validation',
    () async {
      final supplier = Supplier(
        id: supplierId,
        name: 'مورد محدث',
        code: 'PS-$suffix',
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.saveSupplier(supplier);
      expect((await dataSource.suppliers(suffix)).single.name, 'مورد محدث');
      await dataSource.setSupplierActive(supplierId, false);
      expect(
        () => dataSource.saveOrder(order(id: 'inactive-order-$suffix')),
        throwsException,
      );
    },
  );

  test(
    'direct purchase order and partial receiving update stock atomically',
    () async {
      final purchaseOrder = order(id: 'partial-order-$suffix');
      await dataSource.saveOrder(purchaseOrder);
      await dataSource.postReceipt(
        order: purchaseOrder,
        warehouseId: warehouseId,
        receiptDate: now,
        operationId: 'partial-first-$suffix',
        items: [
          PurchasingItem(
            id: '${purchaseOrder.id}-item',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 60,
            unitId: unitId,
          ),
        ],
      );
      final saved = (await dataSource.orders()).firstWhere(
        (value) => value.id == purchaseOrder.id,
      );
      expect(saved.status, PurchaseOrderStatus.partiallyReceived);
      expect(saved.items.single.receivedQuantity, 60);
      await dataSource.postReceipt(
        order: saved,
        warehouseId: warehouseId,
        receiptDate: now,
        operationId: 'partial-second-$suffix',
        items: [
          PurchasingItem(
            id: '${purchaseOrder.id}-item',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 40,
            unitId: unitId,
          ),
        ],
      );
      final complete = (await dataSource.orders()).firstWhere(
        (value) => value.id == purchaseOrder.id,
      );
      expect(complete.status, PurchaseOrderStatus.fullyReceived);
      final stock = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      );
      final transactions = await (await FurnexaDatabase.instance.database)
          .query(
            'stock_transactions',
            where: 'warehouseId = ?',
            whereArgs: [warehouseId],
          );
      expect((stock.single['quantity'] as num).toDouble(), 100);
      expect(transactions, hasLength(2));
    },
  );

  test(
    'purchase receiving posts approved-price inventory and payable values once per receipt',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final accountingRepository = AccountingRepositoryImpl();
      final accountingEntriesBefore = await db.query('journal_entries');
      final supplierPaymentsBefore = await db.query('supplier_payments');
      final request = requestWithItems(
        id: 'accounting-receipt-request-$suffix',
        itemIds: [materialId],
        quantities: [100],
      );
      await dataSource.saveRequest(request);
      await dataSource.changeRequestStatus(
        request.id,
        PurchaseRequestStatus.pending,
      );
      final draft = await dataSource.approveRequest(request.id);
      expect(draft.status, PurchaseOrderStatus.draft);
      expect(await db.query('journal_entries'), accountingEntriesBefore);
      expect(await accountingRepository.purchaseCommitments(), isEmpty);

      final pricedDraft = draft.copyWith(
        items: [draft.items.single.copyWith(unitPrice: 27.5)],
      );
      await dataSource.saveOrder(pricedDraft);
      await dataSource.changeOrderStatus(
        draft.id,
        PurchaseOrderStatus.approved,
      );
      final approvedOrder = (await dataSource.orders()).singleWhere(
        (order) => order.id == draft.id,
      );
      expect(approvedOrder.items.single.unitPrice, 27.5);
      expect(await db.query('journal_entries'), accountingEntriesBefore);
      expect(await db.query('supplier_payments'), supplierPaymentsBefore);
      expect(
        (await accountingRepository.purchaseCommitments())
            .single
            .outstandingValue,
        2750,
      );

      Future<void> receive({
        required double quantity,
        required String operationId,
      }) => dataSource.postReceipt(
        order: approvedOrder,
        warehouseId: warehouseId,
        receiptDate: now,
        operationId: operationId,
        items: [
          PurchasingItem(
            id: approvedOrder.items.single.id,
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: quantity,
            unitId: unitId,
            unitPrice: 999,
          ),
        ],
      );

      await receive(quantity: 80, operationId: 'receive-first-$suffix');
      final firstReceipt = (await dataSource.receipts(draft.id)).single;
      final persistedReceipt = (await db.query(
        'purchase_receipts',
        where: 'id = ?',
        whereArgs: [firstReceipt.id],
      )).single;
      expect(persistedReceipt['purchaseOrderId'], draft.id);
      expect(
        (await db.query(
          'purchase_orders',
          where: 'id = ?',
          whereArgs: [draft.id],
        )).single['purchaseRequestId'],
        request.id,
      );
      final persistedReceiptLine = (await db.query(
        'purchase_receipt_items',
        where: 'purchaseReceiptId = ?',
        whereArgs: [firstReceipt.id],
      )).single;
      expect(
        persistedReceiptLine['purchaseOrderItemId'],
        approvedOrder.items.single.id,
      );
      expect(persistedReceiptLine['receivedQuantity'], 80);
      final firstEntryRows = await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['PURCHASE_RECEIPT', firstReceipt.id],
      );
      expect(firstEntryRows, hasLength(1));
      final firstEntry = firstEntryRows.single;
      expect(firstEntry['date'], now.millisecondsSinceEpoch);
      expect((firstEntry['description'] as String), contains(draft.id));
      expect((firstEntry['description'] as String), contains(request.id));
      final firstLines = await db.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [firstEntry['id']],
      );
      expect(firstLines, hasLength(2));
      final firstDebit = firstLines.fold<double>(
        0,
        (sum, line) => sum + (line['debit'] as num).toDouble(),
      );
      final firstCredit = firstLines.fold<double>(
        0,
        (sum, line) => sum + (line['credit'] as num).toDouble(),
      );
      expect(firstDebit, 2200);
      expect(firstCredit, 2200);
      expect(
        firstLines.every(
          (line) =>
              (line['description'] as String).contains(draft.id) &&
              (line['description'] as String).contains(request.id) &&
              (line['description'] as String).contains(materialId) &&
              (line['description'] as String).contains('27.5'),
        ),
        isTrue,
      );
      expect(
        await db.query(
          'journal_parties',
          where: 'journalEntryId = ? AND partyType = ? AND partyId = ?',
          whereArgs: [firstEntry['id'], 'SUPPLIER', supplierId],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'supplier_payments',
          where: 'supplierId = ?',
          whereArgs: [supplierId],
        ),
        supplierPaymentsBefore,
      );

      await expectLater(
        receive(quantity: 80, operationId: 'receive-first-$suffix'),
        throwsException,
      );
      expect(await dataSource.receipts(draft.id), hasLength(1));
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ?',
          whereArgs: ['PURCHASE_RECEIPT'],
        ),
        hasLength(1),
      );
      final afterFirst = (await dataSource.orders()).singleWhere(
        (order) => order.id == draft.id,
      );
      expect(afterFirst.items.single.receivedQuantity, 80);
      expect(afterFirst.items.single.remainingQuantity, 20);
      expect(afterFirst.items.single.unitPrice, 27.5);
      expect(
        (await accountingRepository.purchaseCommitments())
            .single
            .outstandingValue,
        550,
      );

      await dataSource.postReceipt(
        order: afterFirst,
        warehouseId: warehouseId,
        receiptDate: now.add(const Duration(days: 1)),
        operationId: 'receive-second-$suffix',
        items: [
          PurchasingItem(
            id: afterFirst.items.single.id,
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 20,
            unitId: unitId,
            unitPrice: 999,
          ),
        ],
      );
      final receipts = await dataSource.receipts(draft.id);
      expect(receipts, hasLength(2));
      final secondReceipt = receipts.firstWhere(
        (receipt) => receipt.id != firstReceipt.id,
      );
      final receiptEntries = await db.query(
        'journal_entries',
        where: 'referenceType = ?',
        whereArgs: ['PURCHASE_RECEIPT'],
      );
      expect(receiptEntries, hasLength(2));
      final secondEntry = receiptEntries.singleWhere(
        (entry) => entry['referenceId'] == secondReceipt.id,
      );
      final secondLines = await db.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [secondEntry['id']],
      );
      expect(
        secondLines.fold<double>(
          0,
          (sum, line) => sum + (line['debit'] as num).toDouble(),
        ),
        550,
      );
      expect(
        secondLines.fold<double>(
          0,
          (sum, line) => sum + (line['credit'] as num).toDouble(),
        ),
        550,
      );

      final accountTotals = await db.rawQuery('''
        SELECT a.code, SUM(jl.debit) AS debit, SUM(jl.credit) AS credit
        FROM journal_entries je
        JOIN journal_lines jl ON jl.journalEntryId = je.id
        JOIN accounts a ON a.id = jl.accountId
        WHERE je.referenceType = 'PURCHASE_RECEIPT'
        GROUP BY a.code
      ''');
      expect(
        accountTotals.singleWhere((row) => row['code'] == '1100')['debit'],
        2750,
      );
      expect(
        accountTotals.singleWhere((row) => row['code'] == '2000')['credit'],
        2750,
      );
      final fullyReceived = (await dataSource.orders()).singleWhere(
        (order) => order.id == draft.id,
      );
      expect(fullyReceived.status, PurchaseOrderStatus.fullyReceived);
      expect(fullyReceived.items.single.receivedQuantity, 100);
      expect(fullyReceived.items.single.remainingQuantity, 0);
      expect(fullyReceived.items.single.unitPrice, 27.5);
      expect(fullyReceived.grandTotal, 2750);
      expect(await accountingRepository.purchaseCommitments(), isEmpty);

      final valuationRows = await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, materialId, 'RAW_MATERIAL'],
      );
      expect((valuationRows.single['quantity'] as num).toDouble(), 100);
      expect((valuationRows.single['averageCost'] as num).toDouble(), 27.5);
    },
  );

  test(
    'receiving beyond remaining quantity rolls back receipt, stock, and order quantities',
    () async {
      final purchaseOrder = order(id: 'rollback-order-$suffix');
      await dataSource.saveOrder(purchaseOrder);
      expect(
        () => dataSource.postReceipt(
          order: purchaseOrder,
          warehouseId: warehouseId,
          receiptDate: now,
          operationId: 'overflow-$suffix',
          items: [
            PurchasingItem(
              id: '${purchaseOrder.id}-item',
              itemId: materialId,
              itemType: PurchasingItemType.rawMaterial,
              quantity: 101,
              unitId: unitId,
            ),
          ],
        ),
        throwsException,
      );
      expect((await dataSource.receipts(purchaseOrder.id)), isEmpty);
      expect(
        (await dataSource.orders())
            .firstWhere((value) => value.id == purchaseOrder.id)
            .items
            .single
            .receivedQuantity,
        0,
      );
      final stock = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      );
      expect(stock, isEmpty);
    },
  );

  test(
    'approval automatically creates one linked order with request supplier and lines',
    () async {
      final secondMaterial = await addMaterial('approval-second');
      final thirdMaterial = await addMaterial('approval-third');
      final request = PurchaseRequest(
        id: 'request-$suffix',
        requestNumber: 'PR-$suffix',
        requestDate: now,
        supplierId: supplierId,
        requestedBy: 'المشتريات',
        notes: 'Copy request note',
        status: PurchaseRequestStatus.pending,
        createdAt: now,
        updatedAt: now,
        items: [
          for (final entry in [
            materialId,
            secondMaterial,
            thirdMaterial,
          ].indexed)
            PurchasingItem(
              id: purchasingDocumentItemId('request-$suffix', entry.$1),
              itemId: entry.$2,
              itemType: PurchasingItemType.rawMaterial,
              quantity: (entry.$1 + 2).toDouble(),
              unitId: unitId,
            ),
        ],
      );
      await dataSource.saveRequest(request);

      await dataSource.changeRequestStatus(
        request.id,
        PurchaseRequestStatus.approved,
      );

      final firstApproval = (await dataSource.orders()).single;
      expect(firstApproval.supplierId, supplierId);
      expect(firstApproval.purchaseRequestId, request.id);
      expect(firstApproval.notes, request.notes);
      expect(firstApproval.items, hasLength(3));
      expect(firstApproval.items.map((line) => line.id).toSet(), hasLength(3));
      expect(firstApproval.items.map((line) => line.itemId).toSet(), {
        materialId,
        secondMaterial,
        thirdMaterial,
      });
      expect(firstApproval.items.map((line) => line.quantity).toSet(), {
        2.0,
        3.0,
        4.0,
      });
      expect(
        (await dataSource.requests()).single.status,
        PurchaseRequestStatus.converted,
      );

      final repeatedApproval = await dataSource.approveRequest(request.id);
      expect(repeatedApproval.id, firstApproval.id);
      expect(repeatedApproval.supplierId, supplierId);
      expect(
        repeatedApproval.items.map((line) => line.id).toSet(),
        firstApproval.items.map((line) => line.id).toSet(),
      );
      expect(await dataSource.orders(), hasLength(1));
      expect(
        await (await FurnexaDatabase.instance.database).query(
          'purchase_order_items',
          where: 'purchaseOrderId = ?',
          whereArgs: [firstApproval.id],
        ),
        hasLength(3),
      );
    },
  );

  test('stale cancelled order cannot post receiving', () async {
    final purchaseOrder = order(id: 'stale-order-$suffix');
    await dataSource.saveOrder(purchaseOrder);
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'purchase_orders',
      {'status': 'CANCELLED'},
      where: 'id = ?',
      whereArgs: [purchaseOrder.id],
    );
    expect(
      () => dataSource.postReceipt(
        order: purchaseOrder,
        warehouseId: warehouseId,
        receiptDate: now,
        operationId: 'cancelled-$suffix',
        items: [
          PurchasingItem(
            id: '${purchaseOrder.id}-item',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 1,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );
    expect(await dataSource.receipts(purchaseOrder.id), isEmpty);
    expect(
      await db.query(
        'stock_transactions',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      ),
      isEmpty,
    );
  });

  test(
    'request conversion is idempotent and direct status saves are guarded',
    () async {
      final request = PurchaseRequest(
        id: 'guarded-request-$suffix',
        requestNumber: 'PR-GUARDED-$suffix',
        requestDate: now,
        supplierId: supplierId,
        requestedBy: 'test',
        status: PurchaseRequestStatus.draft,
        createdAt: now,
        updatedAt: now,
        items: [
          PurchasingItem(
            id: 'guarded-request-item-$suffix',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 10,
            unitId: unitId,
          ),
        ],
      );
      await dataSource.saveRequest(request);
      final invalid = PurchaseRequest(
        id: request.id,
        requestNumber: request.requestNumber,
        requestDate: request.requestDate,
        supplierId: request.supplierId,
        requestedBy: request.requestedBy,
        status: PurchaseRequestStatus.converted,
        createdAt: request.createdAt,
        updatedAt: now,
        items: request.items,
      );
      expect(() => dataSource.saveRequest(invalid), throwsException);
      await dataSource.changeRequestStatus(
        request.id,
        PurchaseRequestStatus.pending,
      );
      await dataSource.changeRequestStatus(
        request.id,
        PurchaseRequestStatus.approved,
      );
      final first = order(id: 'converted-once-$suffix');
      final linkedFirst = PurchaseOrder(
        id: first.id,
        orderNumber: first.orderNumber,
        supplierId: first.supplierId,
        purchaseRequestId: request.id,
        orderDate: first.orderDate,
        status: first.status,
        subtotal: first.subtotal,
        discount: first.discount,
        tax: first.tax,
        grandTotal: first.grandTotal,
        createdAt: first.createdAt,
        updatedAt: first.updatedAt,
        items: first.items,
      );
      final generated = await dataSource.convertRequestToOrder(
        request,
        linkedFirst,
      );
      final repeated = await dataSource.convertRequestToOrder(
        request,
        linkedFirst.copyWithForTest(id: 'converted-twice-$suffix'),
      );
      expect(repeated.id, generated.id);
      expect(await dataSource.orders(), hasLength(1));
    },
  );

  test('received order edits and unit mismatches are rejected', () async {
    final purchaseOrder = order(id: 'immutable-order-$suffix');
    await dataSource.saveOrder(purchaseOrder);
    await dataSource.postReceipt(
      order: purchaseOrder,
      warehouseId: warehouseId,
      receiptDate: now,
      operationId: 'immutable-$suffix',
      items: [
        PurchasingItem(
          id: '${purchaseOrder.id}-item',
          itemId: materialId,
          itemType: PurchasingItemType.rawMaterial,
          quantity: 60,
          unitId: unitId,
        ),
      ],
    );
    final received = (await dataSource.orders()).singleWhere(
      (value) => value.id == purchaseOrder.id,
    );
    expect(
      () => dataSource.saveOrder(
        PurchaseOrder(
          id: received.id,
          orderNumber: received.orderNumber,
          supplierId: received.supplierId,
          orderDate: received.orderDate,
          status: received.status,
          subtotal: received.subtotal,
          discount: received.discount,
          tax: received.tax,
          grandTotal: received.grandTotal,
          createdAt: received.createdAt,
          updatedAt: now,
          items: [
            PurchasingItem(
              id: received.items.single.id,
              itemId: materialId,
              itemType: PurchasingItemType.rawMaterial,
              quantity: 50,
              unitId: unitId,
              receivedQuantity: 60,
              unitPrice: 1,
              lineTotal: 100,
            ),
          ],
        ),
      ),
      throwsException,
    );
    final db = await FurnexaDatabase.instance.database;
    await db.insert('units', {
      'id': 'wrong-unit-$suffix',
      'name': 'وحدة خاطئة $suffix',
      'abbreviation': 'WU$suffix',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    expect(
      () => dataSource.saveOrder(
        order(
          id: 'wrong-unit-order-$suffix',
        ).copyWithForTest(itemUnitId: 'wrong-unit-$suffix'),
      ),
      throwsException,
    );
  });

  test(
    'direct purchasing calls require permission and create audit events',
    () async {
      final security = SecurityLocalDataSource();
      final role = await security.createRole(
        name: 'No Purchasing ${DateTime.now().microsecondsSinceEpoch}',
      );
      final user = await security.createUser(
        username: 'no-purchasing-${DateTime.now().microsecondsSinceEpoch}',
        displayName: 'No Purchasing',
        password: 'secret',
        roleId: role.id,
      );
      security.logout();
      await security.login(user.username, 'secret');
      expect(
        () => dataSource.saveSupplier(
          Supplier(
            id: 'blocked-supplier-$suffix',
            name: 'Blocked',
            code: 'BLOCKED-$suffix',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsException,
      );
      security.logout();
      await security.login('admin', 'Furnexa-Test-Admin-2026!');
      await dataSource.saveSupplier(
        Supplier(
          id: 'audited-supplier-$suffix',
          name: 'Audited',
          code: 'AUDITED-$suffix',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final logs = await security.auditLogs(module: 'Purchasing');
      expect(
        logs.any(
          (log) => log.entityType == 'Supplier' && log.action == 'CREATE',
        ),
        isTrue,
      );
    },
  );
}

extension on PurchaseOrder {
  PurchaseOrder copyWithForTest({String? id, String? itemUnitId}) =>
      PurchaseOrder(
        id: id ?? this.id,
        orderNumber: id == null ? orderNumber : 'PO-$id',
        supplierId: supplierId,
        purchaseRequestId: purchaseRequestId,
        orderDate: orderDate,
        expectedDeliveryDate: expectedDeliveryDate,
        status: status,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: grandTotal,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        items: items
            .map(
              (item) => PurchasingItem(
                id: item.id,
                itemId: item.itemId,
                itemType: item.itemType,
                quantity: item.quantity,
                unitId: itemUnitId ?? item.unitId,
                unitPrice: item.unitPrice,
                discount: item.discount,
                tax: item.tax,
                lineTotal: item.lineTotal,
                receivedQuantity: item.receivedQuantity,
                notes: item.notes,
              ),
            )
            .toList(),
      );
}
