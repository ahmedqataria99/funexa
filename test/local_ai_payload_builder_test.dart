import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/features/ai/data/sales_ai_payload_builder.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class _UnauthorizedSecurity extends SecurityLocalDataSource {
  @override
  Future<void> requireFresh(String permission) async {
    throw Exception('Missing permission: $permission');
  }
}

void main() {
  test('payload source is fail-closed and excludes unposted deliveries', () {
    final source = File(
      'lib/features/ai/data/sales_ai_payload_builder.dart',
    ).readAsStringSync();

    expect(source, contains("sd.status = 'DELIVERED'"));
    expect(source, contains('sd.inventoryPosted = 1'));
    expect(source, contains('identitySnapshotStatus = \'VERIFIED\''));
    expect(source, contains('No authorized warehouse scope'));
    expect(source, isNot(contains('ImportExport')));
  });

  test('payload source keeps missing and observed zero states separate', () {
    final source = File(
      'lib/features/ai/data/sales_ai_payload_builder.dart',
    ).readAsStringSync();

    expect(source, contains("'missing'"));
    expect(source, contains("'observed_zero'"));
  });

  test('unauthorized user cannot build Sales AI payload', () async {
    final builder = SalesAiPayloadBuilder(security: _UnauthorizedSecurity());

    await expectLater(
      builder.build(
        periodStart: DateTime.utc(2026, 1, 1),
        periodEnd: DateTime.utc(2026, 1, 31),
        horizonDays: 7,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('exact accepted-return stock transaction pair matches', () {
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 3,
      transactions: _exactPair(quantity: 3),
    );

    expect(result.matched, isTrue);
  });

  test('missing stock transaction excludes accepted return', () {
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 3,
      transactions: const [],
    );

    expect(result.exclusionReason, 'missing_stock_transaction');
  });

  test('incorrect stock transaction reference excludes accepted return', () {
    final transactions = _exactPair(quantity: 3)
      ..forEach((row) {
        row['reference'] = 'SALES_RETURN_ACCEPTED:wrong:item';
      });
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 3,
      transactions: transactions,
    );

    expect(result.exclusionReason, 'incorrect_stock_transaction_reference');
  });

  test('wrong product or variant excludes accepted return', () {
    final transactions = _exactPair(quantity: 3);
    transactions.last['variantId'] = 'other-variant';
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 3,
      transactions: transactions,
    );

    expect(
      result.exclusionReason,
      'wrong_stock_transaction_product_or_variant',
    );
  });

  test('wrong warehouse excludes accepted return', () {
    final transactions = _exactPair(quantity: 3);
    transactions.last['warehouseId'] = 'other-sellable';
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 3,
      transactions: transactions,
    );

    expect(result.exclusionReason, 'wrong_stock_transaction_warehouse');
  });

  test('quantity mismatch excludes accepted return', () {
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 3,
      transactions: _exactPair(quantity: 2),
    );

    expect(result.exclusionReason, 'stock_transaction_quantity_mismatch');
  });

  test('partial accepted quantity matches exact partial pair', () {
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 1.5,
      transactions: _exactPair(quantity: 1.5),
    );

    expect(result.matched, isTrue);
  });

  test('duplicate stock transaction pair excludes accepted return', () {
    final transactions = [
      ..._exactPair(quantity: 3),
      ..._exactPair(quantity: 3).take(1).map((row) => {...row, 'id': 'dup'}),
    ];
    final result = SalesAiStockReconciliationMatcher.match(
      exactReference: 'SALES_RETURN_ACCEPTED:sr-1:item-1',
      sellableWarehouseId: 'wh-sellable',
      quarantineWarehouseId: 'wh-quarantine',
      productId: 'product-1',
      variantId: 'variant-1',
      baseUnitId: 'unit-1',
      inventoryIdentityKind: 'VARIANT',
      acceptedQuantity: 3,
      transactions: transactions,
    );

    expect(result.exclusionReason, 'duplicate_stock_transaction');
  });

  test(
    'rejected and quarantined quantities remain excluded from net demand',
    () {
      final source = File(
        'lib/features/ai/data/sales_ai_payload_builder.dart',
      ).readAsStringSync();

      expect(source, contains('rejected_or_quarantined_excluded'));
      expect(source, contains('rejectedBaseQuantity'));
      expect(source, contains('quarantinedBaseQuantity'));
    },
  );

  test('duplicate return reconciliation is fail-closed', () {
    final source = File(
      'lib/features/ai/data/sales_ai_payload_builder.dart',
    ).readAsStringSync();

    expect(source, contains('reconciledReferences'));
    expect(source, contains('duplicate_return_reconciliation'));
  });

  test('valid delivery stays while unmatched return is excluded', () {
    final source = File(
      'lib/features/ai/data/sales_ai_payload_builder.dart',
    ).readAsStringSync();

    expect(source, contains('final acceptedByDeliveryItem'));
    expect(source, contains('if (!stockMatch.matched)'));
    expect(source, contains('aggregated[key]'));
  });
}

List<Map<String, Object?>> _exactPair({required double quantity}) => [
  {
    'id': 'tx-out',
    'warehouseId': 'wh-quarantine',
    'itemId': 'product-1',
    'itemType': 'PRODUCT',
    'productId': 'product-1',
    'variantId': 'variant-1',
    'inventoryIdentityKind': 'VARIANT',
    'transactionType': 'TRANSFER_OUT',
    'quantity': quantity,
    'unitId': 'unit-1',
    'reference': 'SALES_RETURN_ACCEPTED:sr-1:item-1',
  },
  {
    'id': 'tx-in',
    'warehouseId': 'wh-sellable',
    'itemId': 'product-1',
    'itemType': 'PRODUCT',
    'productId': 'product-1',
    'variantId': 'variant-1',
    'inventoryIdentityKind': 'VARIANT',
    'transactionType': 'TRANSFER_IN',
    'quantity': quantity,
    'unitId': 'unit-1',
    'reference': 'SALES_RETURN_ACCEPTED:sr-1:item-1',
  },
];
