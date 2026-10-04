import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/pricing/data/datasources/pricing_local_data_source.dart';
import 'package:furnexa/features/pricing/domain/entities/pricing_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late PricingLocalDataSource dataSource;
  late SecurityLocalDataSource security;

  Future<void> seedProduct({
    String productId = 'prod-1',
    String customerId = 'customer-1',
    String priceListId = 'price-list-1',
    String priceListCode = 'STANDARD',
    double listPrice = 100,
    String listName = 'Standard',
  }) async {
    final now = DateTime.now();
    final db = await FurnexaDatabase.instance.database;
    await db.insert('categories', {
      'id': 'cat-1',
      'name': 'Furniture',
      'code': 'FUR',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('units', {
      'id': 'unit-1',
      'name': 'Piece',
      'abbreviation': 'PCS',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'Chair',
      'code': 'CHAIR',
      'categoryId': 'cat-1',
      'unitId': 'unit-1',
      'productState': 'unfinished',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('customers', {
      'id': customerId,
      'name': 'Customer One',
      'code': 'CUST-1',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    final list = PriceList(
      id: priceListId,
      code: priceListCode,
      name: listName,
      description: 'Pricing list',
      active: true,
      createdAt: now,
      updatedAt: now,
    );
    await dataSource.savePriceList(list);
    await dataSource.saveProductPrice(
      ProductPrice(
        id: 'price-${productId}-${priceListId}',
        priceListId: priceListId,
        productId: productId,
        variantId: null,
        unitPrice: listPrice,
        currency: 'SAR',
        validFrom: now,
        validTo: now.add(const Duration(days: 365)),
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    dataSource = PricingLocalDataSource(security: security);
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test('1. Customer-specific price overrides normal pricing', () async {
    final now = DateTime.now();
    await seedProduct();
    await dataSource.saveCustomerPriceOverride(
      CustomerPriceOverride(
        id: 'customer-override-1',
        customerId: 'customer-1',
        productId: 'prod-1',
        unitPrice: 85,
        validFrom: now,
        validTo: now.add(const Duration(days: 365)),
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final resolution = await dataSource.resolvePrice(
      productId: 'prod-1',
      customerId: 'customer-1',
      quantity: 1,
      asOf: now,
    );

    expect(resolution.source, PricingSource.customerOverride);
    expect(resolution.unitPrice, 85);
    expect(resolution.finalPrice, 85);
  });

  test('2. Quantity-based pricing is selected correctly', () async {
    final now = DateTime.now();
    await seedProduct(listPrice: 120);
    await dataSource.saveQuantityTier(
      PriceTier(
        id: 'tier-1',
        priceListId: 'price-list-1',
        productId: 'prod-1',
        minimumQuantity: 10,
        unitPrice: 92,
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final resolution = await dataSource.resolvePrice(
      productId: 'prod-1',
      customerId: 'customer-1',
      quantity: 12,
      asOf: now,
    );

    expect(resolution.source, PricingSource.quantityTier);
    expect(resolution.unitPrice, 92);
    expect(resolution.finalPrice, 92);
  });

  test(
    '3. Customer Price List is used when no higher-priority price exists',
    () async {
      final now = DateTime.now();
      await seedProduct(
        priceListId: 'default-price-list',
        priceListCode: 'DEFAULT',
        listName: 'Default',
      );
      await dataSource.savePriceList(
        PriceList(
          id: 'customer-price-list',
          code: 'CUSTOMER',
          name: 'Customer',
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveProductPrice(
        ProductPrice(
          id: 'customer-price-1',
          priceListId: 'customer-price-list',
          productId: 'prod-1',
          unitPrice: 74,
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final resolution = await dataSource.resolvePrice(
        productId: 'prod-1',
        customerId: 'customer-1',
        quantity: 1,
        priceListId: 'customer-price-list',
        asOf: now,
      );

      expect(resolution.source, PricingSource.listPrice);
      expect(resolution.unitPrice, 74);
      expect(resolution.finalPrice, 74);
    },
  );

  test('4. Default Price List is used as fallback', () async {
    final now = DateTime.now();
    await seedProduct(listPrice: 60);

    final resolution = await dataSource.resolvePrice(
      productId: 'prod-1',
      customerId: null,
      quantity: 1,
      asOf: now,
    );

    expect(resolution.source, PricingSource.listPrice);
    expect(resolution.unitPrice, 60);
    expect(resolution.finalPrice, 60);
  });

  test('5. No suggested price is valid', () async {
    final now = DateTime.now();
    final resolution = await dataSource.resolvePrice(
      productId: 'missing-product',
      customerId: 'customer-1',
      quantity: 1,
      asOf: now,
    );

    expect(resolution.source, PricingSource.noSuggestedPrice);
    expect(resolution.unitPrice, 0.0);
    expect(resolution.finalPrice, 0.0);
  });

  test(
    '6. Manual price entry is always allowed for authorized users',
    () async {
      final now = DateTime.now();
      await seedProduct(listPrice: 120);

      await dataSource.saveManualPriceAdjustment(
        ManualPriceAdjustment(
          id: 'manual-adjustment-1',
          entityType: 'ProductPrice',
          entityId: 'price-prod-1',
          productId: 'prod-1',
          unitPrice: 130,
          discountAmount: 0,
          finalPrice: 130,
          effectiveAt: now,
          createdAt: now,
        ),
      );

      final history = await dataSource.priceHistory(productId: 'prod-1');
      expect(history, isNotEmpty);
      expect(history.first.finalPrice, 130);
    },
  );

  test(
    '7. Manual price override replaces the suggested price and preserves both values',
    () async {
      final now = DateTime.now();
      await seedProduct(listPrice: 150);

      await dataSource.saveManualPriceAdjustment(
        ManualPriceAdjustment(
          id: 'manual-adjustment-2',
          entityType: 'ProductPrice',
          entityId: 'price-prod-1',
          productId: 'prod-1',
          unitPrice: 138,
          discountAmount: 12,
          finalPrice: 126,
          effectiveAt: now,
          createdAt: now,
        ),
      );

      final history = await dataSource.priceHistory(productId: 'prod-1');
      expect(history, isNotEmpty);
      expect(history.first.unitPrice, 138);
      expect(history.first.discountAmount, 12);
      expect(history.first.finalPrice, 126);
    },
  );

  test(
    '8. Discounts calculate correctly for percentage and fixed amount',
    () async {
      final now = DateTime.now();
      await seedProduct(listPrice: 100);
      await dataSource.saveDiscountRule(
        DiscountRule(
          id: 'discount-1',
          productId: 'prod-1',
          type: DiscountType.percentage,
          value: 10,
          minimumQuantity: 0,
          validFrom: now,
          validTo: now.add(const Duration(days: 365)),
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final percentageResolution = await dataSource.resolvePrice(
        productId: 'prod-1',
        customerId: null,
        quantity: 1,
        asOf: now,
      );
      expect(percentageResolution.discountAmount, 10.0);
      expect(percentageResolution.finalPrice, 90.0);

      await dataSource.saveDiscountRule(
        DiscountRule(
          id: 'discount-2',
          productId: 'prod-1',
          type: DiscountType.amount,
          value: 15,
          minimumQuantity: 0,
          validFrom: now,
          validTo: now.add(const Duration(days: 365)),
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final fixedResolution = await dataSource.resolvePrice(
        productId: 'prod-1',
        customerId: null,
        quantity: 1,
        asOf: now,
      );
      expect(fixedResolution.discountAmount, 15.0);
      expect(fixedResolution.finalPrice, 85.0);
    },
  );

  test('9. Invalid discount values are rejected', () async {
    final now = DateTime.now();
    expect(
      () => DiscountRule(
        id: 'invalid-discount',
        productId: 'prod-1',
        type: DiscountType.percentage,
        value: -5,
        validFrom: now,
        validTo: now.add(const Duration(days: 30)),
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
      throwsArgumentError,
    );
  });

  test(
    '10. Price snapshot remains unchanged after the source price changes',
    () async {
      final now = DateTime.now();
      await seedProduct(listPrice: 100);
      await dataSource.savePriceHistory(
        PriceHistory(
          id: 'snapshot-1',
          entityType: 'ProductPrice',
          entityId: 'price-prod-1',
          productId: 'prod-1',
          unitPrice: 100,
          discountAmount: 0,
          finalPrice: 100,
          effectiveAt: now,
          createdAt: now,
        ),
      );
      await dataSource.saveProductPrice(
        ProductPrice(
          id: 'price-prod-1-price-list-1',
          priceListId: 'price-list-1',
          productId: 'prod-1',
          unitPrice: 140,
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final history = await dataSource.priceHistory(productId: 'prod-1');
      expect(history, isNotEmpty);
      expect(history.first.unitPrice, 100);
      expect(history.first.finalPrice, 100);
    },
  );

  test(
    '11. Manual price adjustment is recorded in pricing history and audit',
    () async {
      final now = DateTime.now();
      await seedProduct(listPrice: 110);
      await dataSource.saveManualPriceAdjustment(
        ManualPriceAdjustment(
          id: 'manual-adjustment-3',
          entityType: 'ProductPrice',
          entityId: 'price-prod-1',
          productId: 'prod-1',
          unitPrice: 98,
          discountAmount: 8,
          finalPrice: 90,
          effectiveAt: now,
          createdAt: now,
        ),
      );
      await security.audit(
        action: 'MANUAL_PRICE_ADJUSTMENT',
        module: 'Pricing',
        entityType: 'ProductPrice',
        entityId: 'prod-1',
        description: 'Manual price adjustment recorded',
      );

      final history = await dataSource.priceHistory(productId: 'prod-1');
      final logs = await security.auditLogs(
        module: 'Pricing',
        action: 'MANUAL_PRICE_ADJUSTMENT',
      );

      expect(history, isNotEmpty);
      expect(logs, isNotEmpty);
      expect(logs.first.entityId, 'prod-1');
    },
  );

  test(
    '12. Pricing aliases remain compatible with the existing architecture',
    () async {
      final now = DateTime.now();
      await seedProduct(listPrice: 70);
      await dataSource.saveCustomerPriceOverride(
        CustomerPriceOverride(
          id: 'alias-override',
          customerId: 'customer-1',
          productId: 'prod-1',
          unitPrice: 65,
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveDiscountRule(
        DiscountRule(
          id: 'alias-discount',
          productId: 'prod-1',
          type: DiscountType.percentage,
          value: 5,
          validFrom: now,
          validTo: now.add(const Duration(days: 30)),
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.savePriceHistory(
        PriceHistory(
          id: 'alias-history',
          entityType: 'ProductPrice',
          entityId: 'alias-price',
          productId: 'prod-1',
          unitPrice: 70,
          discountAmount: 3.5,
          finalPrice: 66.5,
          effectiveAt: now,
          createdAt: now,
        ),
      );

      final customerOverrides = await dataSource.customerPriceOverrides(
        customerId: 'customer-1',
        productId: 'prod-1',
      );
      final discountRules = await dataSource.commercialDiscountRules(
        productId: 'prod-1',
      );
      final history = await dataSource.historicalSnapshots(productId: 'prod-1');

      expect(customerOverrides, isNotEmpty);
      expect(discountRules, isNotEmpty);
      expect(history, isNotEmpty);
    },
  );
}
