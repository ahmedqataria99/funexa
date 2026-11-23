import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/ai/data/historical_sales_dataset_builder.dart';
import 'package:furnexa/features/ai/data/sales_ai_payload_builder.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:path/path.dart' as p;

class _AuthorizedSellableWarehouseSecurity extends SecurityLocalDataSource {
  @override
  bool get hasUnrestrictedWarehouseAccess => false;

  @override
  Set<String> get authorizedWarehouseIds => {'wh-synthetic-sellable'};

  @override
  Future<void> requireFresh(String permission) async {}

  @override
  void require(String permission) {}
}

int _day(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Prompt 30 synthetic factory Sales pipeline is isolated and reconciled',
    () async {
      final temp = await Directory.systemTemp.createTemp('furnexa_prompt30_');
      final databasePath = p.join(temp.path, 'prompt30_fixture.db');

      await FurnexaDatabase.instance.close();
      await FurnexaDatabase.instance.resetForTesting();
      FurnexaDatabase.setLocalDevelopmentDatabasePath(databasePath);

      try {
        final db = await FurnexaDatabase.instance.database;
        final versionRow = await db.rawQuery('PRAGMA user_version');
        expect(versionRow.single['user_version'], 41);

        await db.transaction((txn) async {
          final now = _day(2026, 1, 1);

          await txn.insert('factories', {
            'id': 'factory-synthetic',
            'name': 'Synthetic Furniture Works',
            'code': 'SYN-FACTORY',
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('warehouses', {
            'id': 'wh-synthetic-sellable',
            'factoryId': 'factory-synthetic',
            'name': 'Synthetic Sellable',
            'code': 'SYN-SELL',
            'purpose': 'SELLABLE',
            'state': 'active',
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('warehouses', {
            'id': 'wh-synthetic-quarantine',
            'factoryId': 'factory-synthetic',
            'name': 'Synthetic Quarantine',
            'code': 'SYN-QC',
            'purpose': 'QUARANTINE',
            'state': 'active',
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('warehouses', {
            'id': 'wh-synthetic-unauthorized',
            'factoryId': 'factory-synthetic',
            'name': 'Synthetic Unauthorized',
            'code': 'SYN-NOSCOPE',
            'purpose': 'SELLABLE',
            'state': 'active',
            'createdAt': now,
            'updatedAt': now,
          });

          await txn.insert('categories', {
            'id': 'cat-synthetic',
            'name': 'Synthetic Furniture',
            'code': 'SYN-CAT',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('units', {
            'id': 'unit-piece',
            'name': 'Synthetic Piece',
            'abbreviation': 'syn-pc',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('units', {
            'id': 'unit-kilogram',
            'name': 'Synthetic Kilogram',
            'abbreviation': 'syn-kg',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });

          await txn.insert('products', {
            'id': 'product-chair',
            'name': 'Synthetic Chair',
            'code': 'SYN-CHAIR',
            'categoryId': 'cat-synthetic',
            'unitId': 'unit-piece',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('product_variants', {
            'id': 'variant-red',
            'productId': 'product-chair',
            'name': 'Synthetic Red',
            'code': 'SYN-RED',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('products', {
            'id': 'product-table',
            'name': 'Synthetic Table',
            'code': 'SYN-TABLE',
            'categoryId': 'cat-synthetic',
            'unitId': 'unit-kilogram',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('product_variants', {
            'id': 'variant-oak',
            'productId': 'product-table',
            'name': 'Synthetic Oak',
            'code': 'SYN-OAK',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });

          await txn.insert('customers', {
            'id': 'customer-synthetic',
            'name': 'Fictional Test Customer',
            'code': 'SYN-CUST',
            'active': 1,
            'createdAt': now,
            'updatedAt': now,
          });
          await txn.insert('sales_orders', {
            'id': 'order-synthetic',
            'orderNumber': 'SYN-ORDER-001',
            'customerId': 'customer-synthetic',
            'orderDate': now,
            'status': 'FULLY_DELIVERED',
            'createdAt': now,
            'updatedAt': now,
          });

          await txn.insert('sales_order_items', {
            'id': 'order-line-chair',
            'salesOrderId': 'order-synthetic',
            'itemId': 'product-chair',
            'itemType': 'PRODUCT',
            'quantity': 20,
            'unitId': 'unit-piece',
            'unitPrice': 1,
            'deliveredQuantity': 22,
            'variantId': 'variant-red',
            'productId': 'product-chair',
            'baseUnitId': 'unit-piece',
            'unitConversionFactor': 1,
            'inventoryIdentityKind': 'VARIANT',
            'identitySnapshotStatus': 'VERIFIED',
          });
          await txn.insert('sales_order_items', {
            'id': 'order-line-table',
            'salesOrderId': 'order-synthetic',
            'itemId': 'product-table',
            'itemType': 'PRODUCT',
            'quantity': 3,
            'unitId': 'unit-kilogram',
            'unitPrice': 1,
            'deliveredQuantity': 3,
            'variantId': 'variant-oak',
            'productId': 'product-table',
            'baseUnitId': 'unit-kilogram',
            'unitConversionFactor': 1,
            'inventoryIdentityKind': 'VARIANT',
            'identitySnapshotStatus': 'VERIFIED',
          });

          Future<void> addDelivery(
            String id,
            String number,
            int date,
            String warehouse,
            String status,
            int posted,
            String orderLine,
            double quantity,
            String unit,
            String product,
            String? variant,
            String deliveryLineId,
          ) async {
            await txn.insert('sales_deliveries', {
              'id': id,
              'deliveryNumber': number,
              'salesOrderId': 'order-synthetic',
              'warehouseId': warehouse,
              'deliveryDate': date,
              'status': status,
              'inventoryPosted': posted,
              'createdAt': now,
            });
            await txn.insert('sales_delivery_items', {
              'id': deliveryLineId,
              'salesDeliveryId': id,
              'salesOrderItemId': orderLine,
              'deliveredQuantity': quantity,
              'unitId': unit,
              'productId': product,
              'variantId': variant,
              'baseUnitId': unit,
              'baseQuantity': quantity,
              'unitConversionFactor': 1,
              'inventoryIdentityKind': 'VARIANT',
              'identitySnapshotStatus': 'VERIFIED',
            });
          }

          await addDelivery(
            'delivery-chair-jan10',
            'SYN-DL-101',
            _day(2026, 1, 10),
            'wh-synthetic-sellable',
            'DELIVERED',
            1,
            'order-line-chair',
            10,
            'unit-piece',
            'product-chair',
            'variant-red',
            'delivery-line-chair-jan10',
          );
          await addDelivery(
            'delivery-chair-jan15',
            'SYN-DL-102',
            _day(2026, 1, 15),
            'wh-synthetic-sellable',
            'DELIVERED',
            1,
            'order-line-chair',
            5,
            'unit-piece',
            'product-chair',
            'variant-red',
            'delivery-line-chair-jan15',
          );
          await addDelivery(
            'delivery-chair-feb10',
            'SYN-DL-103',
            _day(2026, 2, 10),
            'wh-synthetic-sellable',
            'DELIVERED',
            1,
            'order-line-chair',
            7,
            'unit-piece',
            'product-chair',
            'variant-red',
            'delivery-line-chair-feb10',
          );
          await addDelivery(
            'delivery-table-jan12',
            'SYN-DL-104',
            _day(2026, 1, 12),
            'wh-synthetic-sellable',
            'DELIVERED',
            1,
            'order-line-table',
            3,
            'unit-kilogram',
            'product-table',
            'variant-oak',
            'delivery-line-table-jan12',
          );
          await addDelivery(
            'delivery-unposted',
            'SYN-DL-105',
            _day(2026, 1, 20),
            'wh-synthetic-sellable',
            'DELIVERED',
            0,
            'order-line-chair',
            100,
            'unit-piece',
            'product-chair',
            'variant-red',
            'delivery-line-unposted',
          );
          await addDelivery(
            'delivery-unauthorized',
            'SYN-DL-106',
            _day(2026, 1, 21),
            'wh-synthetic-unauthorized',
            'DELIVERED',
            1,
            'order-line-chair',
            200,
            'unit-piece',
            'product-chair',
            'variant-red',
            'delivery-line-unauthorized',
          );

          Future<void> addAcceptedReturn({
            required String returnId,
            required String returnNumber,
            required String sourceLine,
            required double accepted,
            required double rejected,
            required double quarantined,
            required int date,
          }) async {
            await txn.insert('sales_returns', {
              'id': returnId,
              'returnNumber': returnNumber,
              'salesOrderId': 'order-synthetic',
              'salesDeliveryId': sourceLine.contains('table')
                  ? 'delivery-table-jan12'
                  : null,
              'customerId': 'customer-synthetic',
              'warehouseId': 'wh-synthetic-sellable',
              'returnDate': date,
              'status': 'COMPLETED',
              'createdAt': now,
              'updatedAt': now,
            });
            final returnItemId = '${returnId}-item';
            await txn.insert('sales_return_items', {
              'id': returnItemId,
              'salesReturnId': returnId,
              'itemId': sourceLine.contains('table')
                  ? 'product-table'
                  : 'product-chair',
              'itemType': 'PRODUCT',
              'quantity': accepted + rejected + quarantined,
              'unitId': sourceLine.contains('table')
                  ? 'unit-kilogram'
                  : 'unit-piece',
              'qualityStatus': rejected > 0 ? 'REJECTED' : 'APPROVED',
              'sourceDeliveryItemId': sourceLine,
              'productId': sourceLine.contains('table')
                  ? 'product-table'
                  : 'product-chair',
              'variantId': sourceLine.contains('table')
                  ? 'variant-oak'
                  : 'variant-red',
              'baseUnitId': sourceLine.contains('table')
                  ? 'unit-kilogram'
                  : 'unit-piece',
              'unitConversionFactor': 1,
              'baseQuantity': accepted + rejected + quarantined,
              'inventoryIdentityKind': 'VARIANT',
              'identitySnapshotStatus': 'VERIFIED',
              'createdAt': now,
            });
            await txn.insert('sales_return_receipts', {
              'id': '${returnId}-receipt',
              'receiptNumber': '${returnNumber}-RCPT',
              'salesReturnId': returnId,
              'warehouseId': 'wh-synthetic-quarantine',
              'receiptDate': date,
              'createdAt': now,
            });
            await txn.insert('sales_return_receipt_items', {
              'id': '${returnId}-receipt-item',
              'receiptId': '${returnId}-receipt',
              'salesReturnItemId': returnItemId,
              'quantity': accepted + rejected + quarantined,
              'baseQuantity': accepted + rejected + quarantined,
            });
            await txn.insert('quality_inspections', {
              'id': '${returnId}-inspection',
              'inspectionNumber': '${returnNumber}-QC',
              'sourceType': 'SALES_RETURN',
              'sourceId': returnId,
              'warehouseId': 'wh-synthetic-quarantine',
              'itemId': sourceLine.contains('table')
                  ? 'product-table'
                  : 'product-chair',
              'itemType': 'PRODUCT',
              'inspectionDate': date,
              'status': 'COMPLETED',
              'result': 'PASSED',
              'productId': sourceLine.contains('table')
                  ? 'product-table'
                  : 'product-chair',
              'variantId': sourceLine.contains('table')
                  ? 'variant-oak'
                  : 'variant-red',
              'createdAt': now,
              'updatedAt': now,
            });
            await txn.insert('quality_inspection_items', {
              'id': '${returnId}-inspection-item',
              'inspectionId': '${returnId}-inspection',
              'itemId': sourceLine.contains('table')
                  ? 'product-table'
                  : 'product-chair',
              'itemType': 'PRODUCT',
              'requestedQuantity': accepted + rejected + quarantined,
              'inspectedQuantity': accepted + rejected + quarantined,
              'acceptedQuantity': accepted,
              'rejectedQuantity': rejected,
              'sourceReturnItemId': returnItemId,
              'productId': sourceLine.contains('table')
                  ? 'product-table'
                  : 'product-chair',
              'variantId': sourceLine.contains('table')
                  ? 'variant-oak'
                  : 'variant-red',
              'inventoryIdentityKind': 'VARIANT',
              'identitySnapshotStatus': 'VERIFIED',
              'baseUnitId': sourceLine.contains('table')
                  ? 'unit-kilogram'
                  : 'unit-piece',
              'unitConversionFactor': 1,
              'requestedBaseQuantity': accepted + rejected + quarantined,
              'inspectedBaseQuantity': accepted + rejected + quarantined,
              'acceptedBaseQuantity': accepted,
              'rejectedBaseQuantity': rejected,
              'quarantinedQuantity': quarantined,
              'quarantinedBaseQuantity': quarantined,
              'result': quarantined > 0 ? 'QUARANTINED' : 'PASSED',
              'createdAt': now,
            });
          }

          await addAcceptedReturn(
            returnId: 'return-valid',
            returnNumber: 'SYN-R-001',
            sourceLine: 'delivery-line-chair-jan10',
            accepted: 2,
            rejected: 0,
            quarantined: 0,
            date: _day(2026, 1, 20),
          );
          await addAcceptedReturn(
            returnId: 'return-zero',
            returnNumber: 'SYN-R-002',
            sourceLine: 'delivery-line-chair-jan15',
            accepted: 5,
            rejected: 0,
            quarantined: 0,
            date: _day(2026, 1, 21),
          );
          await addAcceptedReturn(
            returnId: 'return-missing',
            returnNumber: 'SYN-R-003',
            sourceLine: 'delivery-line-table-jan12',
            accepted: 1,
            rejected: 0,
            quarantined: 0,
            date: _day(2026, 1, 22),
          );
          await addAcceptedReturn(
            returnId: 'return-duplicate',
            returnNumber: 'SYN-R-004',
            sourceLine: 'delivery-line-chair-feb10',
            accepted: 1,
            rejected: 0,
            quarantined: 0,
            date: _day(2026, 2, 11),
          );
          await addAcceptedReturn(
            returnId: 'return-mismatch',
            returnNumber: 'SYN-R-005',
            sourceLine: 'delivery-line-chair-feb10',
            accepted: 1,
            rejected: 1,
            quarantined: 1,
            date: _day(2026, 2, 12),
          );

          Future<void> addStockPair(
            String idPrefix,
            String returnId,
            double quantity,
            String warehouseOut,
            String warehouseIn,
            String product,
            String variant,
            String unit,
          ) async {
            final exact = 'SALES_RETURN_ACCEPTED:$returnId:${returnId}-item';
            await txn.insert('stock_transactions', {
              'id': '${idPrefix}-out',
              'warehouseId': warehouseOut,
              'itemId': product,
              'itemType': 'PRODUCT',
              'transactionType': 'TRANSFER_OUT',
              'quantity': quantity,
              'unitId': unit,
              'reference': exact,
              'transactionDate': now,
              'createdAt': now,
              'productId': product,
              'variantId': variant,
              'inventoryIdentityKind': 'VARIANT',
            });
            await txn.insert('stock_transactions', {
              'id': '${idPrefix}-in',
              'warehouseId': warehouseIn,
              'itemId': product,
              'itemType': 'PRODUCT',
              'transactionType': 'TRANSFER_IN',
              'quantity': quantity,
              'unitId': unit,
              'reference': exact,
              'transactionDate': now,
              'createdAt': now,
              'productId': product,
              'variantId': variant,
              'inventoryIdentityKind': 'VARIANT',
            });
          }

          await addStockPair(
            'stock-valid',
            'return-valid',
            2,
            'wh-synthetic-quarantine',
            'wh-synthetic-sellable',
            'product-chair',
            'variant-red',
            'unit-piece',
          );
          await addStockPair(
            'stock-zero',
            'return-zero',
            5,
            'wh-synthetic-quarantine',
            'wh-synthetic-sellable',
            'product-chair',
            'variant-red',
            'unit-piece',
          );

          final duplicateExact =
              'SALES_RETURN_ACCEPTED:return-duplicate:return-duplicate-item';
          for (final suffix in ['a', 'b', 'c']) {
            await txn.insert('stock_transactions', {
              'id': 'stock-duplicate-$suffix',
              'warehouseId': suffix == 'c'
                  ? 'wh-synthetic-sellable'
                  : 'wh-synthetic-quarantine',
              'itemId': 'product-chair',
              'itemType': 'PRODUCT',
              'transactionType': suffix == 'c' ? 'TRANSFER_IN' : 'TRANSFER_OUT',
              'quantity': 1,
              'unitId': 'unit-piece',
              'reference': duplicateExact,
              'transactionDate': now,
              'createdAt': now,
              'productId': 'product-chair',
              'variantId': 'variant-red',
              'inventoryIdentityKind': 'VARIANT',
            });
          }

          await addStockPair(
            'stock-mismatch',
            'return-mismatch',
            1,
            'wh-synthetic-unauthorized',
            'wh-synthetic-sellable',
            'product-chair',
            'variant-red',
            'unit-piece',
          );
        });

        final payloadBuilder = SalesAiPayloadBuilder(
          security: _AuthorizedSellableWarehouseSecurity(),
          database: () async => db,
        );
        final payload = await payloadBuilder.build(
          periodStart: DateTime.utc(2026, 1, 1),
          periodEnd: DateTime.utc(2026, 2, 28),
          horizonDays: 28,
        );
        final dataset = HistoricalSalesDatasetValidator.validate(
          payload: payload,
          minimumObservedRows: 1,
        );

        expect(payload['sales']['contract_version'], 'sales-demand-v1');
        expect(dataset.rows, isNotEmpty);
        final observations = payload['sales']['observations'] as List;
        final warehouseTokens = observations
            .map((row) => row['warehouse_token'] as String)
            .toSet();
        expect(warehouseTokens, hasLength(1));
        final warehouseToken = warehouseTokens.single;
        final chairObservation = observations.firstWhere(
          (row) =>
              (row['gross_delivered_base_quantity'] as num).toDouble() == 10,
        );
        final tableObservation = observations.firstWhere(
          (row) =>
              (row['gross_delivered_base_quantity'] as num).toDouble() == 3,
        );
        final chairProductToken = chairObservation['product_token'] as String;
        final chairVariantToken = chairObservation['variant_token'] as String;
        final tableProductToken = tableObservation['product_token'] as String;
        final tableVariantToken = tableObservation['variant_token'] as String;
        expect(
          dataset.rows.every((row) => row['warehouse_id'] == warehouseToken),
          isTrue,
        );
        expect(warehouseToken, isNot('wh-synthetic-sellable'));
        expect(warehouseToken, isNot('wh-synthetic-quarantine'));
        expect(dataset.coverage.warehouseScopeViolationCount, 0);

        final chairRows = dataset.rows
            .where(
              (row) =>
                  row['product_id'] == chairProductToken &&
                  row['variant_id'] == chairVariantToken,
            )
            .toList();
        final chairGross = chairRows.fold<double>(
          0,
          (sum, row) => sum + (row['delivered_quantity'] as num).toDouble(),
        );
        final chairAccepted = chairRows.fold<double>(
          0,
          (sum, row) =>
              sum + (row['accepted_return_quantity'] as num).toDouble(),
        );
        final chairNet = chairRows.fold<double>(
          0,
          (sum, row) => sum + (row['net_demand_quantity'] as num).toDouble(),
        );

        expect(chairGross, 22);
        expect(chairAccepted, 7);
        expect(chairNet, 15);
        expect(dataset.coverage.observedZeroRowCount, 1);
        expect(dataset.coverage.observedPositiveRowCount, greaterThan(0));

        final tableRows = dataset.rows
            .where(
              (row) =>
                  row['product_id'] == tableProductToken &&
                  row['variant_id'] == tableVariantToken,
            )
            .toList();
        expect(
          tableRows.fold<double>(
            0,
            (sum, row) => sum + (row['delivered_quantity'] as num).toDouble(),
          ),
          3,
        );

        expect(
          dataset.coverage.unmatchedReturnRowCount,
          greaterThanOrEqualTo(3),
        );
        expect(
          dataset.coverage.dataQualityFlags,
          contains('UNMATCHED_RETURNS_EXCLUDED'),
        );
        expect(dataset.coverage.dataQualityFlags, contains('MISSING_PERIODS'));
        expect(dataset.coverage.missingDateCount, greaterThanOrEqualTo(0));

        final payloadSales = payload['sales'] as Map<String, dynamic>;
        final exclusions =
            payloadSales['excluded_counts'] as Map<String, dynamic>;
        expect(exclusions['missing_stock_transaction'], 1);
        expect(
          exclusions['duplicate_stock_transaction'],
          greaterThanOrEqualTo(1),
        );
        expect(
          exclusions['wrong_stock_transaction_warehouse'],
          greaterThanOrEqualTo(1),
        );
        expect(
          exclusions['rejected_or_quarantined_excluded'],
          greaterThanOrEqualTo(1),
        );

        expect(databasePath, isNot(contains('furnexa.db')));
        expect(databasePath, contains('prompt30_fixture.db'));
      } finally {
        await FurnexaDatabase.instance.close();
        if (await temp.exists()) await temp.delete(recursive: true);
        FurnexaDatabase.setLocalDevelopmentDatabasePath(
          p.join(Directory.systemTemp.path, 'prompt30_should_not_open.db'),
        );
      }
    },
  );
}
