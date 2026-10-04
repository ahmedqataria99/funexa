import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/pricing/domain/entities/pricing_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class PricingLocalDataSource {
  PricingLocalDataSource({SecurityLocalDataSource? security})
    : security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource security;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<List<PriceList>> priceLists([String query = '']) async {
    security.require('PRICING_VIEW');
    return _search('pricing_lists', query, ['name', 'code'], PriceList.fromMap);
  }

  Future<List<ProductPrice>> productPrices({
    String? priceListId,
    String? productId,
    String? variantId,
  }) async {
    security.require('PRICING_VIEW');
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (priceListId != null && priceListId.isNotEmpty) {
      clauses.add('priceListId = ?');
      args.add(priceListId);
    }
    if (productId != null && productId.isNotEmpty) {
      clauses.add('productId = ?');
      args.add(productId);
    }
    if (variantId != null) {
      clauses.add('variantId = ?');
      args.add(variantId);
    }
    final rows = await db.query(
      'product_prices',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'unitPrice ASC',
    );
    return rows.map(ProductPrice.fromMap).toList();
  }

  Future<List<CustomerPriceOverride>> customerPrices({
    String? customerId,
    String? productId,
    String? variantId,
  }) async {
    security.require('PRICING_VIEW');
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (customerId != null && customerId.isNotEmpty) {
      clauses.add('customerId = ?');
      args.add(customerId);
    }
    if (productId != null && productId.isNotEmpty) {
      clauses.add('productId = ?');
      args.add(productId);
    }
    if (variantId != null) {
      clauses.add('variantId = ?');
      args.add(variantId);
    }
    final rows = await db.query(
      'customer_price_overrides',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'unitPrice ASC',
    );
    return rows.map(CustomerPriceOverride.fromMap).toList();
  }

  Future<List<CustomerPriceOverride>> customerPriceOverrides({
    String? customerId,
    String? productId,
    String? variantId,
  }) => customerPrices(
    customerId: customerId,
    productId: productId,
    variantId: variantId,
  );

  Future<List<PriceTier>> quantityTiers({
    String? priceListId,
    String? productId,
    String? variantId,
  }) async {
    security.require('PRICING_VIEW');
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (priceListId != null && priceListId.isNotEmpty) {
      clauses.add('priceListId = ?');
      args.add(priceListId);
    }
    if (productId != null && productId.isNotEmpty) {
      clauses.add('productId = ?');
      args.add(productId);
    }
    if (variantId != null) {
      clauses.add('variantId = ?');
      args.add(variantId);
    }
    final rows = await db.query(
      'price_tiers',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'minimumQuantity DESC',
    );
    return rows.map(PriceTier.fromMap).toList();
  }

  Future<List<DiscountRule>> discountRules({
    String? customerId,
    String? productId,
    String? variantId,
  }) async {
    security.require('PRICING_VIEW');
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (customerId != null && customerId.isNotEmpty) {
      clauses.add('(customerId IS NULL OR customerId = ?)');
      args.add(customerId);
    }
    if (productId != null && productId.isNotEmpty) {
      clauses.add('(productId IS NULL OR productId = ?)');
      args.add(productId);
    }
    if (variantId != null) {
      clauses.add('(variantId IS NULL OR variantId = ?)');
      args.add(variantId);
    }
    final rows = await db.query(
      'discount_rules',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'minimumQuantity DESC, value DESC',
    );
    return rows.map(DiscountRule.fromMap).toList();
  }

  Future<List<DiscountRule>> commercialDiscountRules({
    String? customerId,
    String? productId,
    String? variantId,
  }) => discountRules(
    customerId: customerId,
    productId: productId,
    variantId: variantId,
  );

  Future<List<PriceHistory>> priceHistory({
    String? productId,
    String? variantId,
  }) async {
    security.require('PRICING_VIEW');
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (productId != null && productId.isNotEmpty) {
      clauses.add('productId = ?');
      args.add(productId);
    }
    if (variantId != null) {
      clauses.add('variantId = ?');
      args.add(variantId);
    }
    final rows = await db.query(
      'price_history',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'effectiveAt DESC',
    );
    return rows.map(PriceHistory.fromMap).toList();
  }

  Future<List<PriceHistory>> historicalSnapshots({
    String? productId,
    String? variantId,
  }) => priceHistory(productId: productId, variantId: variantId);

  Future<void> saveManualPriceAdjustment(ManualPriceAdjustment value) =>
      savePriceHistory(value);

  Future<void> savePriceList(PriceList value) async {
    _requireEdit();
    final db = await _db;
    await db.transaction((txn) async {
      if (value.isDefault) {
        await txn.update(
          'pricing_lists',
          {'isDefault': 0},
          where: 'id != ?',
          whereArgs: [value.id],
        );
        await txn.update(
          'price_lists',
          {'isDefault': 0},
          where: 'id != ?',
          whereArgs: [value.id],
        );
      }
      await _saveExecutor(txn, 'pricing_lists', value.id, value.toMap());
      await _saveExecutor(txn, 'price_lists', value.id, value.toMap());
    });
    await security.audit(
      action: value.isDefault ? 'DEFAULT_PRICE_LIST' : 'PRICE_LIST_SAVE',
      module: 'Pricing',
      entityType: 'PriceList',
      entityId: value.id,
      description: 'Price list saved',
    );
  }

  Future<void> assignCustomerPriceList({
    required String customerId,
    required String priceListId,
  }) async {
    _requireEdit();
    final db = await _db;
    await db.transaction((txn) async {
      final customers = await txn.query(
        'customers',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [customerId],
        limit: 1,
      );
      final lists = await txn.query(
        'pricing_lists',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [priceListId],
        limit: 1,
      );
      if (customers.isEmpty || lists.isEmpty) {
        throw Exception('العميل أو قائمة الأسعار غير موجودة أو غير نشطة');
      }
      await txn.insert(
        'customer_price_list_assignments',
        {
          'customerId': customerId,
          'priceListId': priceListId,
          'assignedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await security.audit(
      action: 'CUSTOMER_PRICE_LIST_ASSIGN',
      module: 'Pricing',
      entityType: 'Customer',
      entityId: customerId,
      description: 'Customer price list assigned',
    );
  }

  Future<void> saveProductPrice(ProductPrice value) async {
    _requireEdit();
    await _save('product_prices', value.id, value.toMap(), [
      'pricing_product_prices',
    ]);
  }

  Future<void> saveCustomerPriceOverride(CustomerPriceOverride value) async {
    _requireEdit();
    await _save('customer_price_overrides', value.id, value.toMap(), [
      'customer_prices',
    ]);
  }

  Future<void> saveQuantityTier(PriceTier value) async {
    _requireEdit();
    await _save('price_tiers', value.id, value.toMap(), ['pricing_tiers']);
  }

  Future<void> saveDiscountRule(DiscountRule value) async {
    _requireEdit();
    await _save('discount_rules', value.id, value.toMap(), [
      'commercial_discount_rules',
    ]);
  }

  Future<void> savePriceHistory(PriceHistory value) async {
    _requireEdit();
    await _save('price_history', value.id, value.toMap(), ['pricing_history']);
  }

  Future<PricingResolution> resolvePrice({
    required String productId,
    String? variantId,
    String? customerId,
    required double quantity,
    DateTime? asOf,
    String? priceListId,
  }) async {
    security.require('PRICING_VIEW');
    if (quantity <= 0) throw ArgumentError('الكمية يجب أن تكون أكبر من صفر');
    final now = asOf ?? DateTime.now();
    final db = await _db;
    final products = await db.query(
      'products',
      columns: ['id'],
      where: 'id = ? AND active = 1',
      whereArgs: [productId],
      limit: 1,
    );
    if (products.isEmpty) {
      return _noSuggestedPrice(productId, variantId, customerId, quantity);
    }
    if (customerId != null && customerId.isNotEmpty) {
      final customers = await db.query(
        'customers',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customers.isEmpty) {
        return _noSuggestedPrice(productId, variantId, customerId, quantity);
      }
    }

    var effectivePriceListId = priceListId;
    if (!await _isPriceListValid(db, effectivePriceListId, now)) {
      effectivePriceListId = null;
    }
    if (effectivePriceListId == null && customerId != null) {
      final assignments = await db.query(
        'customer_price_list_assignments',
        where: 'customerId = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (assignments.isNotEmpty) {
        final assignedId = assignments.single['priceListId'] as String;
        if (await _isPriceListValid(db, assignedId, now)) {
          effectivePriceListId = assignedId;
        }
      }
    }
    if (effectivePriceListId == null) {
      final defaults = await db.query(
        'pricing_lists',
        columns: ['id'],
        where: 'isDefault = 1 AND active = 1',
        limit: 1,
      );
      if (defaults.isNotEmpty) {
        final defaultId = defaults.single['id'] as String;
        if (await _isPriceListValid(db, defaultId, now)) {
          effectivePriceListId = defaultId;
        }
      }
    }

    final listPrice = await _activeListPrice(
      productId: productId,
      variantId: variantId,
      priceListId: effectivePriceListId,
      asOf: now,
    );
    final override = await _activeCustomerOverride(
      customerId: customerId,
      productId: productId,
      variantId: variantId,
      asOf: now,
    );
    final tier = await _activeTier(
      productId: productId,
      variantId: variantId,
      priceListId: effectivePriceListId,
      quantity: quantity,
      asOf: now,
    );

    final double basePrice =
        override?.unitPrice ?? tier?.unitPrice ?? listPrice?.unitPrice ?? 0.0;
    final selectedSource = override != null
        ? PricingSource.customerOverride
        : tier != null
        ? PricingSource.quantityTier
        : listPrice != null
        ? PricingSource.listPrice
        : PricingSource.noSuggestedPrice;

    final discount = await _activeDiscount(
      customerId: customerId,
      productId: productId,
      variantId: variantId,
      quantity: quantity,
      asOf: now,
    );
    final double discountAmount = discount == null
        ? 0.0
        : discount.type == DiscountType.percentage
        ? basePrice * discount.value / 100.0
        : discount.value.toDouble();
    if (discountAmount > basePrice) {
      throw Exception('الخصم يتجاوز سعر الوحدة');
    }
    final double finalPrice = basePrice - discountAmount;

    return PricingResolution(
      productId: productId,
      variantId: variantId,
      customerId: customerId,
      quantity: quantity,
      unitPrice: basePrice,
      discountAmount: discountAmount,
      finalPrice: finalPrice,
      source: selectedSource,
    );
  }

  PricingResolution _noSuggestedPrice(
    String productId,
    String? variantId,
    String? customerId,
    double quantity,
  ) => PricingResolution(
    productId: productId,
    variantId: variantId,
    customerId: customerId,
    quantity: quantity,
    unitPrice: 0,
    discountAmount: 0,
    finalPrice: 0,
    source: PricingSource.noSuggestedPrice,
  );

  Future<bool> _isPriceListValid(
    DatabaseExecutor db,
    String? priceListId,
    DateTime asOf,
  ) async {
    if (priceListId == null || priceListId.isEmpty) return false;
    final rows = await db.query(
      'pricing_lists',
      where: 'id = ? AND active = 1',
      whereArgs: [priceListId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final from = rows.single['validFrom'] as int?;
    final to = rows.single['validTo'] as int?;
    final timestamp = asOf.millisecondsSinceEpoch;
    return (from == null || timestamp >= from) &&
        (to == null || timestamp <= to);
  }

  Future<void> _requireEdit() {
    security.require('PRICING_EDIT');
    return Future.value();
  }

  Future<ProductPrice?> _activeListPrice({
    required String productId,
    String? variantId,
    String? priceListId,
    required DateTime asOf,
  }) async {
    final db = await _db;
    final clauses = <String>['productId = ?', 'active = 1'];
    final args = <Object?>[productId];
    if (priceListId != null && priceListId.isNotEmpty) {
      clauses.add('priceListId = ?');
      args.add(priceListId);
    }
    if (variantId != null) {
      clauses.add('variantId = ?');
      args.add(variantId);
    } else {
      clauses.add('(variantId IS NULL OR variantId = ?)');
      args.add('');
    }
    final rows = await db.query(
      'product_prices',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'unitPrice DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final lowerBound = row['validFrom'] as int?;
    final upperBound = row['validTo'] as int?;
    final matchesDate =
        (lowerBound == null || asOf.millisecondsSinceEpoch >= lowerBound) &&
        (upperBound == null || asOf.millisecondsSinceEpoch <= upperBound);
    return matchesDate ? ProductPrice.fromMap(row) : null;
  }

  Future<CustomerPriceOverride?> _activeCustomerOverride({
    required String? customerId,
    required String productId,
    String? variantId,
    required DateTime asOf,
  }) async {
    if (customerId == null || customerId.isEmpty) return null;
    final db = await _db;
    final rows = await db.query(
      'customer_price_overrides',
      where:
          'customerId = ? AND productId = ? AND active = 1 AND (variantId IS NULL OR variantId = ?)',
      whereArgs: [customerId, productId, variantId ?? ''],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final override = CustomerPriceOverride.fromMap(rows.first);
    final lowerBound = override.validFrom?.millisecondsSinceEpoch;
    final upperBound = override.validTo?.millisecondsSinceEpoch;
    final matchesDate =
        (lowerBound == null || asOf.millisecondsSinceEpoch >= lowerBound) &&
        (upperBound == null || asOf.millisecondsSinceEpoch <= upperBound);
    return matchesDate ? override : null;
  }

  Future<PriceTier?> _activeTier({
    required String productId,
    String? variantId,
    String? priceListId,
    required double quantity,
    required DateTime asOf,
  }) async {
    final db = await _db;
    final clauses = <String>['productId = ?', 'active = 1'];
    final args = <Object?>[productId];
    if (priceListId != null && priceListId.isNotEmpty) {
      clauses.add('priceListId = ?');
      args.add(priceListId);
    }
    if (variantId != null) {
      clauses.add('variantId = ?');
      args.add(variantId);
    } else {
      clauses.add('(variantId IS NULL OR variantId = ?)');
      args.add('');
    }
    final rows = await db.query(
      'price_tiers',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'minimumQuantity DESC',
    );
    for (final row in rows) {
      final tier = PriceTier.fromMap(row);
      if (tier.minimumQuantity <= quantity) return tier;
    }
    return null;
  }

  Future<DiscountRule?> _activeDiscount({
    required String? customerId,
    required String productId,
    String? variantId,
    required double quantity,
    required DateTime asOf,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'discount_rules',
      where:
          'active = 1 AND minimumQuantity <= ? AND (customerId IS NULL OR customerId = ?) AND (productId IS NULL OR productId = ?) AND (variantId IS NULL OR variantId = ?)',
      whereArgs: [quantity, customerId ?? '', productId, variantId ?? ''],
      orderBy: 'minimumQuantity DESC, value DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final rule = DiscountRule.fromMap(rows.first);
    final lowerBound = rule.validFrom?.millisecondsSinceEpoch;
    final upperBound = rule.validTo?.millisecondsSinceEpoch;
    final matchesDate =
        (lowerBound == null || asOf.millisecondsSinceEpoch >= lowerBound) &&
        (upperBound == null || asOf.millisecondsSinceEpoch <= upperBound);
    return matchesDate ? rule : null;
  }

  Future<List<T>> _search<T>(
    String table,
    String query,
    List<String> columns,
    T Function(Map<String, Object?>) fromMap,
  ) async {
    final db = await _db;
    final normalized = query.trim().toLowerCase();
    final where = normalized.isEmpty
        ? null
        : columns.map((column) => 'LOWER($column) LIKE ?').join(' OR ');
    final args = normalized.isEmpty
        ? null
        : columns.map((_) => '%$normalized%').toList();
    final rows = await db.query(
      table,
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return rows.map(fromMap).toList();
  }

  Future<void> _saveExecutor(
    DatabaseExecutor db,
    String table,
    String id,
    Map<String, Object?> values,
  ) async {
    final count = await db.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) await db.insert(table, values);
  }

  Future<void> _save(
    String table,
    String id,
    Map<String, Object?> values, [
    List<String> aliasTables = const [],
  ]) async {
    final db = await _db;
    final targets = <String>{table, ...aliasTables}.toList();
    for (final target in targets) {
      final count = await db.update(
        target,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        await db.insert(target, values);
      }
    }
  }
}
