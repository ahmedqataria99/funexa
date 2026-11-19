import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/returns_quality/data/datasources/returns_quality_local_data_source.dart';
import 'package:furnexa/features/returns_quality/domain/entities/returns_quality_entities.dart';
import 'package:furnexa/features/returns_quality/presentation/pages/purchase_returns_page.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecurityLocalDataSource security;
  late ReturnsQualityLocalDataSource dataSource;
  late String suffix;
  late String supplierId;
  late String warehouseId;
  late String unitId;
  late String materialId;
  late String orderId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', DatabaseTestHelper.adminPassword);
    dataSource = ReturnsQualityLocalDataSource(null, security);
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    supplierId = 'purchase-returns-ui-supplier-$suffix';
    warehouseId = 'purchase-returns-ui-warehouse-$suffix';
    unitId = 'purchase-returns-ui-unit-$suffix';
    materialId = 'purchase-returns-ui-material-$suffix';
    orderId = 'purchase-returns-ui-order-$suffix';
    final db = await FurnexaDatabase.instance.database;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': 'purchase-returns-ui-factory-$suffix',
      'name': 'Purchase Returns UI Factory',
      'code': 'PRUIF-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': 'purchase-returns-ui-factory-$suffix',
      'name': 'Purchase Returns UI Warehouse',
      'code': 'PRUIW-$suffix',
      'purpose': 'SELLABLE',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'Piece',
      'abbreviation': 'pc-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': 'purchase-returns-ui-category-$suffix',
      'name': 'UI category',
      'code': 'PRUIC-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('raw_materials', {
      'id': materialId,
      'name': 'UI Return Material',
      'code': 'PRUIM-$suffix',
      'categoryId': 'purchase-returns-ui-category-$suffix',
      'unitId': unitId,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('suppliers', {
      'id': supplierId,
      'name': 'UI Return Supplier',
      'code': 'PRUIS-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('purchase_orders', {
      'id': orderId,
      'orderNumber': 'PO-PRUI-$suffix',
      'supplierId': supplierId,
      'orderDate': stamp,
      'status': 'APPROVED',
      'subtotal': 80,
      'discount': 0,
      'tax': 0,
      'grandTotal': 80,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('purchase_order_items', {
      'id': 'purchase-returns-ui-order-item-$suffix',
      'purchaseOrderId': orderId,
      'itemId': materialId,
      'productId': materialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 10,
      'unitId': unitId,
      'baseUnitId': unitId,
      'unitConversionFactor': 1,
      'baseQuantity': 10,
      'receivedQuantity': 10,
      'receivedBaseQuantity': 10,
      'inventoryIdentityKind': 'BASE',
      'identitySnapshotStatus': 'VERIFIED',
      'unitPrice': 8,
      'discount': 0,
      'tax': 0,
      'lineTotal': 80,
    });
    await db.insert('purchase_receipts', {
      'id': 'purchase-returns-ui-receipt-$suffix',
      'receiptNumber': 'GR-PRUI-$suffix',
      'purchaseOrderId': orderId,
      'warehouseId': warehouseId,
      'receiptDate': stamp,
      'createdAt': stamp,
    });
    await db.insert('purchase_receipt_items', {
      'id': 'purchase-returns-ui-receipt-item-$suffix',
      'purchaseReceiptId': 'purchase-returns-ui-receipt-$suffix',
      'purchaseOrderItemId': 'purchase-returns-ui-order-item-$suffix',
      'receivedQuantity': 10,
      'productId': materialId,
      'unitId': unitId,
      'baseUnitId': unitId,
      'unitConversionFactor': 1,
      'baseQuantity': 10,
      'inventoryIdentityKind': 'BASE',
      'identitySnapshotStatus': 'VERIFIED',
    });
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  Widget app(Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: PurchaseReturnsPage(security: security, dataSource: dataSource),
  );

  testWidgets(
    'Purchase Returns list has localized empty state and create action',
    (tester) async {
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Purchase Returns'), findsOneWidget);
      expect(find.text('No Purchase Returns'), findsOneWidget);
      expect(find.text('Create Purchase Return'), findsOneWidget);
    },
  );

  testWidgets('Purchase Returns list shows a persisted request', (
    tester,
  ) async {
    await dataSource.createPurchaseReturn(
      id: 'purchase-returns-ui-return-$suffix',
      returnNumber: 'PR-UI-$suffix',
      purchaseOrderId: orderId,
      supplierId: supplierId,
      warehouseId: warehouseId,
      returnDate: DateTime(2026, 11, 6),
      reason: 'Quality issue',
      items: [
        PurchaseReturnItem(
          id: 'purchase-returns-ui-return-item-$suffix',
          itemId: materialId,
          itemType: 'RAW_MATERIAL',
          quantity: 2,
          unitId: unitId,
          baseUnitId: unitId,
          unitConversionFactor: 1,
          baseQuantity: 2,
          unitPrice: 8,
          inventoryIdentityKind: 'BASE',
          identitySnapshotStatus: 'VERIFIED',
        ),
      ],
    );
    await tester.pumpWidget(app(const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('مرتجعات المشتريات'), findsOneWidget);
    expect(find.text('PR-UI-$suffix'), findsOneWidget);
    expect(find.text('UI Return Supplier'), findsOneWidget);
    expect(find.text('بانتظار الاستلام'), findsOneWidget);
  });

  testWidgets('create action opens the source selection workflow', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Purchase Return'));
    await tester.pumpAndSettle();
    expect(find.text('Supplier'), findsOneWidget);
    expect(find.text('Original purchase order'), findsOneWidget);
  });
}
