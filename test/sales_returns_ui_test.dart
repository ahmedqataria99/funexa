import 'package:material_ui/material_ui.dart' hide GlobalMaterialLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/returns_quality/data/datasources/returns_quality_local_data_source.dart';
import 'package:furnexa/features/returns_quality/domain/entities/returns_quality_entities.dart';
import 'package:furnexa/features/returns_quality/presentation/pages/sales_returns_page.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecurityLocalDataSource security;
  late ReturnsQualityLocalDataSource dataSource;
  late String suffix;
  late DateTime now;
  late String warehouseId;
  late String quarantineWarehouseId;
  late String unitId;
  late String productId;
  late String customerId;
  late String salesOrderId;
  late String deliveryId;
  late String deliveryItemId;
  late String returnItemId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', DatabaseTestHelper.adminPassword);
    dataSource = ReturnsQualityLocalDataSource(null, security);
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 11, 5);
    final stamp = now.millisecondsSinceEpoch;
    warehouseId = 'sales-return-ui-sellable-$suffix';
    quarantineWarehouseId = 'sales-return-ui-quarantine-$suffix';
    unitId = 'sales-return-ui-unit-$suffix';
    productId = 'sales-return-ui-product-$suffix';
    customerId = 'sales-return-ui-customer-$suffix';
    salesOrderId = 'sales-return-ui-order-$suffix';
    deliveryId = 'sales-return-ui-delivery-$suffix';
    deliveryItemId = 'sales-return-ui-delivery-item-$suffix';
    returnItemId = 'sales-return-ui-item-$suffix';
    final db = await FurnexaDatabase.instance.database;
    await db.insert('factories', {
      'id': 'sales-return-ui-factory-$suffix',
      'name': 'UI Returns Factory',
      'code': 'SRUI-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': 'sales-return-ui-factory-$suffix',
      'name': 'Sellable UI Warehouse',
      'code': 'SRUI-S-$suffix',
      'purpose': 'SELLABLE',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': quarantineWarehouseId,
      'factoryId': 'sales-return-ui-factory-$suffix',
      'name': 'Quarantine UI Warehouse',
      'code': 'SRUI-Q-$suffix',
      'purpose': 'QUARANTINE',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'Piece',
      'abbreviation': 'pc$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': 'sales-return-ui-category-$suffix',
      'name': 'UI Category',
      'code': 'SRUIC-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'UI Return Product',
      'code': 'SRUIP-$suffix',
      'categoryId': 'sales-return-ui-category-$suffix',
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('customers', {
      'id': customerId,
      'name': 'UI Return Customer',
      'code': 'SRUICU-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('sales_orders', {
      'id': salesOrderId,
      'orderNumber': 'SO-UI-$suffix',
      'customerId': customerId,
      'orderDate': stamp,
      'status': 'FULLY_DELIVERED',
      'subtotal': 100,
      'discount': 0,
      'tax': 0,
      'grandTotal': 100,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('sales_order_items', {
      'id': 'sales-return-ui-order-item-$suffix',
      'salesOrderId': salesOrderId,
      'itemId': productId,
      'productId': productId,
      'itemType': 'PRODUCT',
      'quantity': 5,
      'unitId': unitId,
      'baseUnitId': unitId,
      'unitConversionFactor': 1,
      'baseQuantity': 5,
      'deliveredQuantity': 5,
      'deliveredBaseQuantity': 5,
      'inventoryIdentityKind': 'BASE',
      'identitySnapshotStatus': 'VERIFIED',
      'unitPrice': 20,
      'discount': 0,
      'tax': 0,
      'lineTotal': 100,
    });
    await db.insert('sales_deliveries', {
      'id': deliveryId,
      'deliveryNumber': 'DL-UI-$suffix',
      'salesOrderId': salesOrderId,
      'warehouseId': warehouseId,
      'deliveryDate': stamp,
      'status': 'DELIVERED',
      'createdAt': stamp,
    });
    await db.insert('sales_delivery_items', {
      'id': deliveryItemId,
      'salesDeliveryId': deliveryId,
      'salesOrderItemId': 'sales-return-ui-order-item-$suffix',
      'deliveredQuantity': 5,
      'unitId': unitId,
      'productId': productId,
      'baseUnitId': unitId,
      'unitConversionFactor': 1,
      'baseQuantity': 5,
      'inventoryIdentityKind': 'BASE',
      'identitySnapshotStatus': 'VERIFIED',
      'unitRevenue': 20,
      'unitCogs': 8,
    });
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  Future<void> createPendingReturn({
    String returnNumber = 'SR-UI-RETURN',
  }) async {
    await dataSource.createSalesReturn(
      id: 'sales-return-ui-return-$suffix',
      returnNumber: '$returnNumber-$suffix',
      salesOrderId: salesOrderId,
      customerId: customerId,
      warehouseId: warehouseId,
      returnDate: now,
      salesDeliveryId: deliveryId,
      items: [
        SalesReturnItem(
          id: returnItemId,
          itemId: productId,
          itemType: 'PRODUCT',
          quantity: 2,
          unitId: unitId,
          baseUnitId: unitId,
          baseQuantity: 2,
          identitySnapshotStatus: 'VERIFIED',
          sourceDeliveryItemId: deliveryItemId,
        ),
      ],
    );
  }

  testWidgets('Sales Returns content supports vertical wheel-style scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 500));
    await tester.pumpWidget(
      _app(SalesReturnsPage(security: security, dataSource: dataSource)),
    );
    await _pumpUntil(tester, find.text('Sales Returns'));
    final scrollable = find.byType(SingleChildScrollView).first;
    expect(scrollable, findsOneWidget);
    final view = tester.widget<SingleChildScrollView>(scrollable);
    expect(view.controller, isNotNull);
    await tester.drag(scrollable, const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 300));
    expect(view.controller!.position.pixels, greaterThan(0));
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('empty state and create action reflect persisted access', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(SalesReturnsPage(security: security, dataSource: dataSource)),
    );
    await _pumpUntil(tester, find.text('No sales returns'));
    expect(find.text('No sales returns'), findsOneWidget);
    expect(find.text('Create Return'), findsOneWidget);
  });

  testWidgets('populated list supports search and status filtering', (
    tester,
  ) async {
    await createPendingReturn();
    await tester.pumpWidget(
      _app(SalesReturnsPage(security: security, dataSource: dataSource)),
    );
    await _pumpUntil(tester, find.textContaining('SR-UI-RETURN-$suffix'));
    expect(find.textContaining('SR-UI-RETURN-$suffix'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'not-a-return');
    await tester.pumpAndSettle();
    expect(find.text('No sales returns'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'UI Return Customer');
    await tester.pumpAndSettle();
    expect(find.textContaining('SR-UI-RETURN-$suffix'), findsOneWidget);
  });

  testWidgets('creation prevents continuing without a delivered source', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(SalesReturnsPage(security: security, dataSource: dataSource)),
    );
    await _pumpUntil(tester, find.text('Create Return'));
    await tester.tap(find.text('Create Return'));
    await _pumpUntil(tester, find.text('Search delivery, order, or customer'));
    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();
    expect(find.text('Select a delivered sale'), findsWidgets);
  });

  testWidgets('details shows receipt and QC stages before approval', (
    tester,
  ) async {
    await createPendingReturn();
    final receiptId = 'sales-return-ui-receipt-$suffix';
    await dataSource.receiveSalesReturn(
      returnId: 'sales-return-ui-return-$suffix',
      receiptId: receiptId,
      receiptNumber: 'SRR-UI-$suffix',
      quarantineWarehouseId: quarantineWarehouseId,
      receiptDate: now,
      items: [
        SalesReturnReceiptItem(salesReturnItemId: returnItemId, quantity: 2),
      ],
    );
    await tester.pumpWidget(
      _app(
        SalesReturnDetailsPage(
          returnId: 'sales-return-ui-return-$suffix',
          security: security,
          dataSource: dataSource,
        ),
      ),
    );
    await _pumpUntil(tester, find.text('Record inspection'));
    expect(find.text('Quarantine UI Warehouse'), findsOneWidget);
    expect(find.text('Record inspection'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Approve return'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'approved detail shows persisted transfer and accounting result',
    (tester) async {
      await createPendingReturn();
      await dataSource.receiveSalesReturn(
        returnId: 'sales-return-ui-return-$suffix',
        receiptId: 'sales-return-ui-receipt-$suffix',
        receiptNumber: 'SRR-UI-$suffix',
        quarantineWarehouseId: quarantineWarehouseId,
        receiptDate: now,
        items: [
          SalesReturnReceiptItem(salesReturnItemId: returnItemId, quantity: 2),
        ],
      );
      await dataSource.createQualityInspection(
        id: 'sales-return-ui-inspection-$suffix',
        inspectionNumber: 'SRI-UI-$suffix',
        sourceType: 'SALES_RETURN',
        sourceId: 'sales-return-ui-return-$suffix',
        warehouseId: quarantineWarehouseId,
        itemId: productId,
        itemType: 'PRODUCT',
        inspectionDate: now,
        status: QualityInspectionStatus.completed,
        items: [
          QualityInspectionItem(
            id: 'sales-return-ui-inspection-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            requestedQuantity: 2,
            inspectedQuantity: 2,
            acceptedQuantity: 1,
            rejectedQuantity: 1,
            sourceReturnItemId: returnItemId,
            productId: productId,
            identitySnapshotStatus: 'VERIFIED',
            unitId: unitId,
            baseUnitId: unitId,
            unitConversionFactor: 1,
          ),
        ],
      );
      await dataSource.updateSalesReturnStatus(
        'sales-return-ui-return-$suffix',
        ReturnStatus.approved,
      );
      final journal = (await (await FurnexaDatabase.instance.database).query(
        'journal_entries',
        columns: ['entryNumber'],
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['SALES_RETURN', 'sales-return-ui-return-$suffix'],
      )).single;
      await tester.pumpWidget(
        _app(
          SalesReturnDetailsPage(
            returnId: 'sales-return-ui-return-$suffix',
            security: security,
            dataSource: dataSource,
          ),
        ),
      );
      await _pumpUntil(tester, find.text(journal['entryNumber'] as String));
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('Quarantine UI Warehouse'), findsNothing);
      expect(find.text(journal['entryNumber'] as String), findsOneWidget);
    },
  );

  testWidgets('users without return edit permission do not see create action', (
    tester,
  ) async {
    security.logout();
    await tester.pumpWidget(
      _app(SalesReturnsPage(security: security, dataSource: dataSource)),
    );
    await _pumpUntil(tester, find.text('Unable to load records'));
    expect(find.text('Create Return'), findsNothing);
  });
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(useMaterial3: true),
  home: home,
);

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
  fail('Timed out waiting for $finder');
}
