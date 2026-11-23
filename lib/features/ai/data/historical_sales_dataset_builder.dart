import 'package:furnexa/features/ai/data/sales_ai_payload_builder.dart';

class HistoricalSalesCoverageReport {
  const HistoricalSalesCoverageReport({
    required this.periodStart,
    required this.periodEnd,
    required this.rowCount,
    required this.identityCount,
    required this.observedRowCount,
    required this.missingRowCount,
    required this.observedZeroRowCount,
    required this.observedPositiveRowCount,
    required this.exclusionCount,
    required this.duplicateRowCount,
    required this.negativeQuantityRowCount,
    required this.missingIdentityRowCount,
    required this.unitMismatchRowCount,
    required this.unmatchedReturnRowCount,
    required this.missingDateCount,
    required this.warehouseScopeViolationCount,
    required this.insufficientHistoricalCoverage,
    required this.dataQualityFlags,
  });

  final String periodStart;
  final String periodEnd;
  final int rowCount;
  final int identityCount;
  final int observedRowCount;
  final int missingRowCount;
  final int observedZeroRowCount;
  final int observedPositiveRowCount;
  final int exclusionCount;
  final int duplicateRowCount;
  final int negativeQuantityRowCount;
  final int missingIdentityRowCount;
  final int unitMismatchRowCount;
  final int unmatchedReturnRowCount;
  final int missingDateCount;
  final int warehouseScopeViolationCount;
  final bool insufficientHistoricalCoverage;
  final List<String> dataQualityFlags;

  Map<String, dynamic> toMap() => {
    'period_start': periodStart,
    'period_end': periodEnd,
    'row_count': rowCount,
    'identity_count': identityCount,
    'observed_row_count': observedRowCount,
    'missing_row_count': missingRowCount,
    'observed_zero_row_count': observedZeroRowCount,
    'observed_positive_row_count': observedPositiveRowCount,
    'exclusion_count': exclusionCount,
    'duplicate_row_count': duplicateRowCount,
    'negative_quantity_row_count': negativeQuantityRowCount,
    'missing_identity_row_count': missingIdentityRowCount,
    'unit_mismatch_row_count': unitMismatchRowCount,
    'unmatched_return_row_count': unmatchedReturnRowCount,
    'missing_date_count': missingDateCount,
    'warehouse_scope_violation_count': warehouseScopeViolationCount,
    'insufficient_historical_coverage': insufficientHistoricalCoverage,
    'data_quality_flags': dataQualityFlags,
  };
}

class HistoricalSalesDataset {
  const HistoricalSalesDataset({
    required this.contractVersion,
    required this.periodStart,
    required this.periodEnd,
    required this.rows,
    required this.coverage,
  });

  final String contractVersion;
  final String periodStart;
  final String periodEnd;
  final List<Map<String, dynamic>> rows;
  final HistoricalSalesCoverageReport coverage;

  Map<String, dynamic> toMap() => {
    'contract_version': contractVersion,
    'purpose': 'demand_forecasting',
    'period_start': periodStart,
    'period_end': periodEnd,
    'rows': rows,
    'coverage': coverage.toMap(),
  };
}

class HistoricalSalesDatasetValidator {
  static HistoricalSalesDataset validate({
    required Map<String, dynamic> payload,
    int minimumObservedRows = 1,
  }) {
    final sales = payload['sales'];
    if (sales is! Map<String, dynamic>) {
      throw const FormatException('Missing Sales payload');
    }

    final periodStart = sales['period_start']?.toString();
    final periodEnd = sales['period_end']?.toString();
    final observations = sales['observations'];
    if (periodStart == null || periodEnd == null || observations is! List) {
      throw const FormatException('Invalid historical Sales payload');
    }

    final start = DateTime.tryParse(periodStart);
    final end = DateTime.tryParse(periodEnd);
    if (start == null || end == null || end.isBefore(start)) {
      throw const FormatException('Invalid historical date range');
    }

    final outputRows = <Map<String, dynamic>>[];
    final seen = <String>{};
    final identities = <String>{};
    final units = <String, String>{};
    var duplicateRowCount = 0;
    var negativeQuantityRowCount = 0;
    var missingIdentityRowCount = 0;
    var unitMismatchRowCount = 0;
    var unmatchedReturnRowCount = 0;
    var warehouseScopeViolationCount = 0;

    for (final value in observations) {
      if (value is! Map) continue;
      final row = Map<String, dynamic>.from(value);
      final date = row['delivery_date']?.toString();
      final parsedDate = date == null ? null : DateTime.tryParse(date);
      if (parsedDate != null &&
          (parsedDate.isBefore(start) || parsedDate.isAfter(end))) {
        negativeQuantityRowCount++;
        continue;
      }
      final productId = row['product_token']?.toString();
      final variantId = row['variant_token']?.toString();
      final warehouseId = row['warehouse_token']?.toString();
      final baseUnitId = row['base_unit_token']?.toString();
      final observedCoverage = row['observed_coverage'] == true;
      final demandState = row['demand_state']?.toString();

      if (date == null ||
          DateTime.tryParse(date) == null ||
          productId == null ||
          productId.isEmpty ||
          warehouseId == null ||
          warehouseId.isEmpty) {
        missingIdentityRowCount++;
        continue;
      }

      final delivered = (row['gross_delivered_base_quantity'] as num?)
          ?.toDouble();
      final acceptedReturn =
          (row['accepted_return_base_quantity'] as num?)?.toDouble() ?? 0;
      final net = (row['net_delivered_base_quantity'] as num?)?.toDouble();
      if (delivered == null ||
          net == null ||
          !delivered.isFinite ||
          !acceptedReturn.isFinite ||
          !net.isFinite ||
          delivered < 0 ||
          acceptedReturn < 0 ||
          net < 0 ||
          (delivered - acceptedReturn - net).abs() > 0.000001) {
        negativeQuantityRowCount++;
        continue;
      }

      if (baseUnitId != null && baseUnitId.isNotEmpty) {
        final identity = '$warehouseId|$productId|${variantId ?? ''}';
        final priorUnit = units[identity];
        if (priorUnit != null && priorUnit != baseUnitId) {
          unitMismatchRowCount++;
          continue;
        }
        units[identity] = baseUnitId;
      }

      final identity = '$warehouseId|$productId|${variantId ?? ''}';
      identities.add(identity);
      final key = '$date|$identity';
      if (!seen.add(key)) {
        duplicateRowCount++;
        continue;
      }

      if (demandState == 'missing' && observedCoverage) {
        negativeQuantityRowCount++;
        continue;
      }
      if (demandState == 'observed_zero' && observedCoverage && net != 0) {
        negativeQuantityRowCount++;
        continue;
      }
      if (demandState == 'observed_positive' && observedCoverage && net <= 0) {
        negativeQuantityRowCount++;
        continue;
      }

      final excluded = row['exclusion_count'] as num?;
      if (excluded != null && excluded.toDouble() > 0) {
        unmatchedReturnRowCount += excluded.toInt();
      }

      outputRows.add({
        'date': date,
        'product_id': productId,
        'variant_id': variantId,
        'warehouse_id': warehouseId,
        'base_unit_id': baseUnitId,
        'delivered_quantity': delivered,
        'accepted_return_quantity': acceptedReturn,
        'net_demand_quantity': net,
        'observed_coverage': observedCoverage,
        'exclusion_count': excluded?.toInt() ?? 0,
        'data_quality_flags': <String>[
          if (!observedCoverage) 'MISSING_PERIOD',
          if (demandState == 'observed_zero') 'OBSERVED_ZERO',
          if (demandState == 'observed_positive') 'OBSERVED_POSITIVE',
        ],
      });
    }

    outputRows.sort((a, b) {
      final dateComparison = (a['date'] as String).compareTo(
        b['date'] as String,
      );
      if (dateComparison != 0) return dateComparison;
      final warehouseComparison = (a['warehouse_id'] as String).compareTo(
        b['warehouse_id'] as String,
      );
      if (warehouseComparison != 0) return warehouseComparison;
      final productComparison = (a['product_id'] as String).compareTo(
        b['product_id'] as String,
      );
      if (productComparison != 0) return productComparison;
      return (a['variant_id']?.toString() ?? '').compareTo(
        b['variant_id']?.toString() ?? '',
      );
    });

    var observedRowCount = 0;
    var missingRowCount = 0;
    var observedZeroRowCount = 0;
    var observedPositiveRowCount = 0;
    final dateSet = <String>{};
    for (final row in outputRows) {
      final date = row['date'] as String;
      dateSet.add(date);
      if (row['observed_coverage'] == true) {
        observedRowCount++;
        if (row['net_demand_quantity'] == 0) {
          observedZeroRowCount++;
        } else {
          observedPositiveRowCount++;
        }
      } else {
        missingRowCount++;
      }
    }

    final excludedCounts = sales['excluded_counts'];
    final unmatchedReturnFromCoverage = excludedCounts is Map
        ? excludedCounts.entries
              .where(
                (entry) =>
                    entry.key.toString().contains('stock') ||
                    entry.key.toString().contains('return') ||
                    entry.key.toString().contains('qc'),
              )
              .fold<int>(0, (sum, entry) {
                final value = entry.value;
                return sum + (value is num ? value.toInt() : 0);
              })
        : 0;
    unmatchedReturnRowCount += unmatchedReturnFromCoverage;

    final missingDateCount = _countMissingCalendarDates(
      start,
      end,
      dateSet,
      outputRows,
    );

    final flags = <String>{
      if (duplicateRowCount > 0) 'DUPLICATE_ROWS',
      if (negativeQuantityRowCount > 0) 'INVALID_QUANTITY',
      if (missingIdentityRowCount > 0) 'MISSING_PRODUCT_OR_WAREHOUSE_IDENTITY',
      if (unitMismatchRowCount > 0) 'UNIT_CONSISTENCY_MISMATCH',
      if (unmatchedReturnRowCount > 0) 'UNMATCHED_RETURNS_EXCLUDED',
      if (missingRowCount > 0) 'MISSING_PERIODS',
      if (missingDateCount > 0) 'DATE_GAPS',
      if (warehouseScopeViolationCount > 0) 'WAREHOUSE_SCOPE_VIOLATION',
    }.toList()..sort();

    final insufficient = observedRowCount < minimumObservedRows;
    if (insufficient) flags.add('INSUFFICIENT_HISTORICAL_COVERAGE');

    return HistoricalSalesDataset(
      contractVersion:
          sales['contract_version']?.toString() ??
          SalesAiPayloadBuilder.contractVersion,
      periodStart: periodStart,
      periodEnd: periodEnd,
      rows: outputRows,
      coverage: HistoricalSalesCoverageReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        rowCount: outputRows.length,
        identityCount: identities.length,
        observedRowCount: observedRowCount,
        missingRowCount: missingRowCount,
        observedZeroRowCount: observedZeroRowCount,
        observedPositiveRowCount: observedPositiveRowCount,
        exclusionCount:
            unmatchedReturnRowCount +
            duplicateRowCount +
            negativeQuantityRowCount +
            missingIdentityRowCount +
            unitMismatchRowCount,
        duplicateRowCount: duplicateRowCount,
        negativeQuantityRowCount: negativeQuantityRowCount,
        missingIdentityRowCount: missingIdentityRowCount,
        unitMismatchRowCount: unitMismatchRowCount,
        unmatchedReturnRowCount: unmatchedReturnRowCount,
        missingDateCount: missingDateCount,
        warehouseScopeViolationCount: warehouseScopeViolationCount,
        insufficientHistoricalCoverage: insufficient,
        dataQualityFlags: flags,
      ),
    );
  }

  static int _countMissingCalendarDates(
    DateTime start,
    DateTime end,
    Set<String> dateSet,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return end.difference(start).inDays + 1;
    var missing = 0;
    for (
      var date = start;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      final dateText = date.toIso8601String().substring(0, 10);
      if (!dateSet.contains(dateText)) missing++;
    }
    return missing;
  }
}

class HistoricalSalesDatasetBuilder {
  HistoricalSalesDatasetBuilder({SalesAiPayloadBuilder? payloadBuilder})
    : _payloadBuilder = payloadBuilder ?? SalesAiPayloadBuilder();

  final SalesAiPayloadBuilder _payloadBuilder;

  Future<HistoricalSalesDataset> build({
    required DateTime periodStart,
    required DateTime periodEnd,
    required int horizonDays,
    int minimumObservedRows = 1,
  }) async {
    final payload = await _payloadBuilder.build(
      periodStart: periodStart,
      periodEnd: periodEnd,
      horizonDays: horizonDays,
    );
    return HistoricalSalesDatasetValidator.validate(
      payload: payload,
      minimumObservedRows: minimumObservedRows,
    );
  }
}
