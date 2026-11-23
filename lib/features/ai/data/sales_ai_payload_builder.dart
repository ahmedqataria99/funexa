import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class SalesAiSelectionOption {
  const SalesAiSelectionOption({
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantName,
  });

  final String warehouseId;
  final String warehouseName;
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;

  String get selectionKey => '$warehouseId|$productId|${variantId ?? ''}';
}

class SalesAiPayloadBuilder {
  SalesAiPayloadBuilder({
    SecurityLocalDataSource? security,
    Future<Database> Function()? database,
  }) : _security = security ?? SecurityLocalDataSource(),
       _database = database ?? (() => FurnexaDatabase.instance.database);

  final SecurityLocalDataSource _security;
  final Future<Database> Function() _database;
  final String _tokenKey = List.generate(
    32,
    (_) => Random.secure().nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  static const contractVersion = 'sales-demand-v1';

  Future<List<SalesAiSelectionOption>> availableSelections() async {
    await _security.requireFresh('SALES_VIEW');
    final warehouseIds = _security.authorizedWarehouseIds.toList()..sort();
    if (!_security.hasUnrestrictedWarehouseAccess && warehouseIds.isEmpty) {
      throw Exception('No authorized warehouse scope');
    }
    final scope = _security.hasUnrestrictedWarehouseAccess
        ? '1 = 1'
        : 'w.id IN (${List.filled(warehouseIds.length, '?').join(',')})';
    final rows = await (await _database()).rawQuery('''
      SELECT DISTINCT
        w.id AS warehouseId,
        w.name AS warehouseName,
        p.id AS productId,
        p.name AS productName,
        sdi.variantId AS variantId,
        pv.name AS variantName
      FROM sales_deliveries sd
      JOIN warehouses w ON w.id = sd.warehouseId
      JOIN sales_delivery_items sdi ON sdi.salesDeliveryId = sd.id
      JOIN sales_order_items soi ON soi.id = sdi.salesOrderItemId
      JOIN products p ON p.id = COALESCE(sdi.productId, soi.productId, soi.itemId)
      LEFT JOIN product_variants pv ON pv.id = sdi.variantId
      WHERE sd.status = 'DELIVERED'
        AND sd.inventoryPosted = 1
        AND sdi.identitySnapshotStatus = 'VERIFIED'
        AND sdi.baseQuantity IS NOT NULL
        AND sdi.baseUnitId IS NOT NULL
        AND sdi.unitConversionFactor IS NOT NULL
        AND soi.salesOrderId = sd.salesOrderId
        AND $scope
      ORDER BY w.name, p.name, pv.name
      ''', warehouseIds);
    return rows
        .map(
          (row) => SalesAiSelectionOption(
            warehouseId: row['warehouseId'] as String,
            warehouseName: row['warehouseName'] as String,
            productId: row['productId'] as String,
            productName: row['productName'] as String,
            variantId: row['variantId'] as String?,
            variantName: row['variantName'] as String?,
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> build({
    required DateTime periodStart,
    required DateTime periodEnd,
    required int horizonDays,
    String? warehouseId,
    String? productId,
    String? variantId,
    bool filterVariant = false,
  }) async {
    await _security.requireFresh('SALES_VIEW');
    _security.require('RETURNS_VIEW');
    _security.require('QUALITY_VIEW');

    final start = DateTime.utc(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final end = DateTime.utc(periodEnd.year, periodEnd.month, periodEnd.day);
    if (end.isBefore(start)) throw ArgumentError('Invalid period');
    if (horizonDays < 1 || horizonDays > 366) {
      throw ArgumentError('Invalid horizon');
    }

    final warehouseIds = _security.authorizedWarehouseIds.toList()..sort();
    if (!_security.hasUnrestrictedWarehouseAccess && warehouseIds.isEmpty) {
      throw Exception('No authorized warehouse scope');
    }

    final db = await _database();
    final endExclusive = end.add(const Duration(days: 1));
    final args = <Object?>[
      start.millisecondsSinceEpoch,
      endExclusive.millisecondsSinceEpoch,
    ];
    final scope = _security.hasUnrestrictedWarehouseAccess
        ? '1 = 1'
        : 'w.id IN (${List.filled(warehouseIds.length, '?').join(',')})';
    if (!_security.hasUnrestrictedWarehouseAccess) args.addAll(warehouseIds);
    if ((warehouseId == null) != (productId == null)) {
      throw ArgumentError(
        'Warehouse and product filters must be provided together',
      );
    }
    final selectionFilters = <String>[];
    if (warehouseId != null && productId != null) {
      selectionFilters.add('w.id = ?');
      selectionFilters.add(
        'COALESCE(sdi.productId, soi.productId, soi.itemId) = ?',
      );
      args
        ..add(warehouseId)
        ..add(productId);
      if (filterVariant) {
        if (variantId == null) {
          selectionFilters.add('sdi.variantId IS NULL');
        } else {
          selectionFilters.add('sdi.variantId = ?');
          args.add(variantId);
        }
      }
    }
    final selectionScope = selectionFilters.isEmpty
        ? ''
        : 'AND ${selectionFilters.join(' AND ')}';

    final deliveryRows = await db.rawQuery('''
      SELECT
        sd.deliveryDate AS deliveryDate,
        w.id AS warehouseId,
        COALESCE(sdi.productId, soi.productId, soi.itemId) AS productId,
        sdi.variantId AS variantId,
        sdi.deliveredQuantity AS deliveredQuantity,
        sdi.baseQuantity AS baseQuantity,
        sdi.baseUnitId AS baseUnitId,
        sdi.unitConversionFactor AS conversionFactor,
        sdi.identitySnapshotStatus AS identityStatus,
        sdi.inventoryIdentityKind AS identityKind,
        sd.id AS deliveryId,
        sdi.id AS deliveryItemId,
        soi.salesOrderId AS salesOrderId,
        soi.id AS salesOrderItemId
      FROM sales_deliveries sd
      JOIN warehouses w ON w.id = sd.warehouseId
      JOIN factories f ON f.id = w.factoryId
      JOIN sales_delivery_items sdi ON sdi.salesDeliveryId = sd.id
      JOIN sales_order_items soi ON soi.id = sdi.salesOrderItemId
      WHERE sd.status = 'DELIVERED'
        AND sd.inventoryPosted = 1
        AND sd.deliveryDate >= ? AND sd.deliveryDate < ?
        AND $scope
        AND sdi.identitySnapshotStatus = 'VERIFIED'
        AND sdi.baseQuantity IS NOT NULL
        AND sdi.baseUnitId IS NOT NULL
        AND sdi.unitConversionFactor IS NOT NULL
        AND COALESCE(sdi.productId, soi.productId, soi.itemId) IS NOT NULL
        AND soi.salesOrderId = sd.salesOrderId
        $selectionScope
      ''', args);

    final acceptedReturnScope = _security.hasUnrestrictedWarehouseAccess
        ? '1 = 1'
        : 'w.id IN (${List.filled(warehouseIds.length, '?').join(',')})';
    final acceptedArgs = <Object?>[
      start.millisecondsSinceEpoch,
      endExclusive.millisecondsSinceEpoch,
    ];
    if (!_security.hasUnrestrictedWarehouseAccess) {
      acceptedArgs.addAll(warehouseIds);
    }

    final acceptedReturnRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(rr.receiptDate, sr.returnDate) AS returnDate,
        sr.id AS salesReturnId,
        sri.id AS salesReturnItemId,
        w.id AS warehouseId,
        rr.warehouseId AS quarantineWarehouseId,
        COALESCE(sri.productId, sri.itemId, sdi.productId) AS productId,
        COALESCE(sri.variantId, sdi.variantId) AS variantId,
        COALESCE(sri.baseUnitId, sdi.baseUnitId, sri.unitId) AS baseUnitId,
        COALESCE(sri.inventoryIdentityKind, sdi.inventoryIdentityKind, 'BASE') AS inventoryIdentityKind,
        sdi.id AS sourceDeliveryItemId,
        SUM(COALESCE(qii.acceptedBaseQuantity, 0)) AS acceptedBaseQuantity,
        SUM(COALESCE(qii.rejectedBaseQuantity, 0)) AS rejectedBaseQuantity,
        SUM(COALESCE(qii.quarantinedBaseQuantity, 0)) AS quarantinedBaseQuantity,
        SUM(COALESCE(qii.inspectedBaseQuantity, 0)) AS inspectedBaseQuantity
      FROM sales_returns sr
      JOIN warehouses w ON w.id = sr.warehouseId
      JOIN factories f ON f.id = w.factoryId
      JOIN sales_return_items sri ON sri.salesReturnId = sr.id
      JOIN sales_return_receipts rr ON rr.salesReturnId = sr.id
      JOIN sales_return_receipt_items rri
        ON rri.receiptId = rr.id AND rri.salesReturnItemId = sri.id
      JOIN sales_delivery_items sdi ON sdi.id = sri.sourceDeliveryItemId
      JOIN sales_deliveries sourceDelivery ON sourceDelivery.id = sdi.salesDeliveryId
      JOIN quality_inspections qi
        ON qi.sourceType = 'SALES_RETURN'
       AND qi.sourceId = sr.id
       AND qi.status = 'COMPLETED'
       AND qi.warehouseId = rr.warehouseId
      JOIN quality_inspection_items qii
        ON qii.inspectionId = qi.id
       AND qii.sourceReturnItemId = sri.id
      WHERE sr.status = 'COMPLETED'
        AND rr.warehouseId != sr.warehouseId
        AND sourceDelivery.warehouseId = sr.warehouseId
        AND sourceDelivery.salesOrderId = sr.salesOrderId
        AND sourceDelivery.status = 'DELIVERED'
        AND sourceDelivery.inventoryPosted = 1
        AND sri.identitySnapshotStatus = 'VERIFIED'
        AND COALESCE(rr.receiptDate, sr.returnDate) >= ?
        AND COALESCE(rr.receiptDate, sr.returnDate) < ?
        AND $acceptedReturnScope
      GROUP BY sr.id, sri.id, w.id, rr.warehouseId, sdi.id,
        sri.productId, sri.itemId, sdi.productId,
        sri.variantId, sdi.variantId,
        sri.baseUnitId, sdi.baseUnitId, sri.unitId,
        sri.inventoryIdentityKind, sdi.inventoryIdentityKind,
        rr.receiptDate, sr.returnDate
      ''',
      <Object?>[...acceptedArgs.take(2), ...acceptedArgs.skip(2)],
    );

    final acceptedByDeliveryItem = <String, double>{};
    final returnCoverage = <String, Map<String, dynamic>>{};
    final reconciledReferences = <String>{};
    final exclusionCounts = <String, int>{
      'missing_stock_transaction': 0,
      'incorrect_stock_transaction_reference': 0,
      'wrong_stock_transaction_product_or_variant': 0,
      'wrong_stock_transaction_warehouse': 0,
      'stock_transaction_quantity_mismatch': 0,
      'duplicate_stock_transaction': 0,
      'duplicate_return_reconciliation': 0,
      'return_qc_reconciliation_mismatch': 0,
      'rejected_or_quarantined_excluded': 0,
      'duplicate_delivery_line': 0,
    };
    for (final row in acceptedReturnRows) {
      if (row['acceptedBaseQuantity'] == null) continue;
      final accepted = (row['acceptedBaseQuantity'] as num).toDouble();
      final rejected = (row['rejectedBaseQuantity'] as num).toDouble();
      final quarantined = (row['quarantinedBaseQuantity'] as num).toDouble();
      final inspected = (row['inspectedBaseQuantity'] as num).toDouble();
      if (!accepted.isFinite ||
          accepted < 0 ||
          !rejected.isFinite ||
          rejected < 0 ||
          !quarantined.isFinite ||
          quarantined < 0 ||
          !inspected.isFinite ||
          inspected < 0) {
        continue;
      }
      if ((accepted + rejected + quarantined - inspected).abs() > 0.000001) {
        exclusionCounts['return_qc_reconciliation_mismatch'] =
            (exclusionCounts['return_qc_reconciliation_mismatch'] ?? 0) + 1;
        continue;
      }
      final sourceDeliveryItemId = row['sourceDeliveryItemId'] as String?;
      final salesReturnId = row['salesReturnId'] as String?;
      final salesReturnItemId = row['salesReturnItemId'] as String?;
      if (sourceDeliveryItemId == null ||
          salesReturnId == null ||
          salesReturnItemId == null) {
        continue;
      }

      if (rejected > 0 || quarantined > 0) {
        exclusionCounts['rejected_or_quarantined_excluded'] =
            (exclusionCounts['rejected_or_quarantined_excluded'] ?? 0) + 1;
      }

      final exactReference =
          'SALES_RETURN_ACCEPTED:$salesReturnId:$salesReturnItemId';
      if (!reconciledReferences.add(exactReference)) {
        exclusionCounts['duplicate_return_reconciliation'] =
            (exclusionCounts['duplicate_return_reconciliation'] ?? 0) + 1;
        continue;
      }

      if (accepted <= 0) continue;
      final productId = row['productId'] as String?;
      final baseUnitId = row['baseUnitId'] as String?;
      final sellableWarehouseId = row['warehouseId'] as String?;
      final quarantineWarehouseId = row['quarantineWarehouseId'] as String?;
      final inventoryIdentityKind = row['inventoryIdentityKind'] as String?;
      if (productId == null ||
          baseUnitId == null ||
          sellableWarehouseId == null ||
          quarantineWarehouseId == null ||
          inventoryIdentityKind == null) {
        continue;
      }
      final stockRows = await db.rawQuery(
        '''
        SELECT id, warehouseId, itemId, itemType, productId, variantId,
          inventoryIdentityKind, transactionType, quantity, unitId, reference
        FROM stock_transactions
        WHERE reference = ? OR reference LIKE ?
        ORDER BY id ASC
        ''',
        [exactReference, 'SALES_RETURN_ACCEPTED:$salesReturnId:%'],
      );
      final stockMatch = SalesAiStockReconciliationMatcher.match(
        exactReference: exactReference,
        sellableWarehouseId: sellableWarehouseId,
        quarantineWarehouseId: quarantineWarehouseId,
        productId: productId,
        variantId: row['variantId'] as String?,
        baseUnitId: baseUnitId,
        inventoryIdentityKind: inventoryIdentityKind,
        acceptedQuantity: accepted,
        transactions: stockRows,
      );
      if (!stockMatch.matched) {
        exclusionCounts[stockMatch.exclusionReason] =
            (exclusionCounts[stockMatch.exclusionReason] ?? 0) + 1;
        continue;
      }

      acceptedByDeliveryItem.update(
        sourceDeliveryItemId,
        (value) => value + accepted,
        ifAbsent: () => accepted,
      );
      returnCoverage[sourceDeliveryItemId] = {
        'warehouseToken': _opaqueToken(row['warehouseId'] as String),
        'productToken': _opaqueToken(row['productId'] as String),
        'variantToken': row['variantId'] == null
            ? null
            : _opaqueToken(row['variantId'] as String),
        'acceptedReturnBaseQuantity': accepted,
        'rejectedReturnBaseQuantity': rejected,
        'quarantinedBaseQuantity': quarantined,
      };
    }

    final observations = <Map<String, dynamic>>[];
    final aggregated = <String, Map<String, dynamic>>{};
    final seenDeliveryItemIds = <String>{};
    for (final row in deliveryRows) {
      final deliveryItemId = row['deliveryItemId'] as String;
      if (!seenDeliveryItemIds.add(deliveryItemId)) {
        exclusionCounts['duplicate_delivery_line'] =
            (exclusionCounts['duplicate_delivery_line'] ?? 0) + 1;
        continue;
      }
      final accepted = acceptedByDeliveryItem[deliveryItemId] ?? 0;
      final gross = (row['baseQuantity'] as num).toDouble();
      final net = gross - accepted;
      if (!net.isFinite || net < 0) continue;

      final date = DateTime.fromMillisecondsSinceEpoch(
        row['deliveryDate'] as int,
      ).toUtc();
      final warehouseToken = _opaqueToken(row['warehouseId'] as String);
      final productToken = _opaqueToken(row['productId'] as String);
      final baseUnitToken = row['baseUnitId'] == null
          ? null
          : _opaqueToken(row['baseUnitId'] as String);
      final variantToken = row['variantId'] == null
          ? null
          : _opaqueToken(row['variantId'] as String);
      final key =
          '${date.toIso8601String().substring(0, 10)}|$warehouseToken|$productToken|${variantToken ?? ''}';
      final previous = aggregated[key];
      if (previous == null) {
        aggregated[key] = {
          'delivery_date': date.toIso8601String().substring(0, 10),
          'warehouse_token': warehouseToken,
          'product_token': productToken,
          'variant_token': variantToken,
          'base_unit_token': baseUnitToken,
          'gross_delivered_base_quantity': gross,
          'accepted_return_base_quantity': accepted,
          'net_delivered_base_quantity': net,
          'observed_coverage': true,
          'demand_state': net == 0 ? 'observed_zero' : 'observed_positive',
        };
      } else {
        previous['gross_delivered_base_quantity'] =
            (previous['gross_delivered_base_quantity'] as num).toDouble() +
            gross;
        previous['accepted_return_base_quantity'] =
            (previous['accepted_return_base_quantity'] as num).toDouble() +
            accepted;
        final combinedNet =
            (previous['gross_delivered_base_quantity'] as num).toDouble() -
            (previous['accepted_return_base_quantity'] as num).toDouble();
        previous['net_delivered_base_quantity'] = combinedNet;
        previous['demand_state'] = combinedNet == 0
            ? 'observed_zero'
            : 'observed_positive';
      }
    }

    observations.addAll(aggregated.values);

    final days = end.difference(start).inDays + 1;
    for (int offset = 0; offset < days; offset++) {
      final date = start.add(Duration(days: offset));
      final dateText = date.toIso8601String().substring(0, 10);
      final identities = <String>{};
      for (final row in observations) {
        identities.add(
          '${row['warehouse_token']}|${row['product_token']}|${row['variant_token'] ?? ''}',
        );
      }
      for (final identity in identities) {
        final parts = identity.split('|');
        final key = '$dateText|${parts[0]}|${parts[1]}|${parts[2]}';
        if (!aggregated.containsKey(key)) {
          observations.add({
            'delivery_date': dateText,
            'warehouse_token': parts[0],
            'product_token': parts[1],
            'variant_token': parts[2].isEmpty ? null : parts[2],
            'base_unit_token': null,
            'gross_delivered_base_quantity': 0,
            'accepted_return_base_quantity': 0,
            'net_delivered_base_quantity': 0,
            'observed_coverage': false,
            'demand_state': 'missing',
          });
        }
      }
    }

    return {
      'request_id': 'sales-${DateTime.now().millisecondsSinceEpoch}',
      'sales': {
        'contract_version': contractVersion,
        'purpose': 'demand_forecasting',
        'period_start': start.toIso8601String().substring(0, 10),
        'period_end': end.toIso8601String().substring(0, 10),
        'horizon_days': horizonDays,
        'observations': observations,
        'excluded_counts': {
          'not_delivered_or_not_posted': deliveryRows.isEmpty ? 0 : 0,
          ...exclusionCounts,
        },
      },
    };
  }

  String _opaqueToken(String source) {
    final digest = Hmac(
      sha256,
      utf8.encode(_tokenKey),
    ).convert(utf8.encode(source));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}

class SalesAiStockReconciliationResult {
  const SalesAiStockReconciliationResult({
    required this.matched,
    required this.exclusionReason,
  });

  final bool matched;
  final String exclusionReason;
}

class SalesAiStockReconciliationMatcher {
  static SalesAiStockReconciliationResult match({
    required String exactReference,
    required String sellableWarehouseId,
    required String quarantineWarehouseId,
    required String productId,
    required String? variantId,
    required String baseUnitId,
    required String inventoryIdentityKind,
    required double acceptedQuantity,
    required List<Map<String, Object?>> transactions,
  }) {
    if (transactions.isEmpty) {
      return const SalesAiStockReconciliationResult(
        matched: false,
        exclusionReason: 'missing_stock_transaction',
      );
    }

    final exact = transactions
        .where((row) => row['reference'] == exactReference)
        .toList();
    if (exact.isEmpty) {
      return const SalesAiStockReconciliationResult(
        matched: false,
        exclusionReason: 'incorrect_stock_transaction_reference',
      );
    }

    final uniqueIds = exact.map((row) => row['id']?.toString()).toSet();
    if (exact.length != 2 || uniqueIds.length != 2) {
      return const SalesAiStockReconciliationResult(
        matched: false,
        exclusionReason: 'duplicate_stock_transaction',
      );
    }

    final outRows = exact
        .where((row) => row['transactionType'] == 'TRANSFER_OUT')
        .toList();
    final inRows = exact
        .where((row) => row['transactionType'] == 'TRANSFER_IN')
        .toList();
    if (outRows.length != 1 || inRows.length != 1) {
      return const SalesAiStockReconciliationResult(
        matched: false,
        exclusionReason: 'duplicate_stock_transaction',
      );
    }

    final out = outRows.single;
    final inRow = inRows.single;
    if (out['warehouseId'] != quarantineWarehouseId ||
        inRow['warehouseId'] != sellableWarehouseId) {
      return const SalesAiStockReconciliationResult(
        matched: false,
        exclusionReason: 'wrong_stock_transaction_warehouse',
      );
    }

    for (final row in [out, inRow]) {
      if (row['itemType'] != 'PRODUCT' ||
          row['productId'] != productId ||
          row['variantId'] != variantId ||
          row['inventoryIdentityKind'] != inventoryIdentityKind ||
          row['unitId'] != baseUnitId) {
        return const SalesAiStockReconciliationResult(
          matched: false,
          exclusionReason: 'wrong_stock_transaction_product_or_variant',
        );
      }
      final quantity = (row['quantity'] as num?)?.toDouble();
      if (quantity == null ||
          !quantity.isFinite ||
          (quantity - acceptedQuantity).abs() > 0.000001) {
        return const SalesAiStockReconciliationResult(
          matched: false,
          exclusionReason: 'stock_transaction_quantity_mismatch',
        );
      }
    }

    return const SalesAiStockReconciliationResult(
      matched: true,
      exclusionReason: '',
    );
  }
}
