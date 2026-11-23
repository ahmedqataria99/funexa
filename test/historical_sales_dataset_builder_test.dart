import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/features/ai/data/historical_sales_dataset_builder.dart';

Map<String, dynamic> _payload({List<Map<String, dynamic>>? observations}) {
  return {
    'sales': {
      'contract_version': 'sales-demand-v1',
      'period_start': '2026-01-01',
      'period_end': '2026-01-03',
      'observations': observations ?? _validObservations(),
      'excluded_counts': {
        'missing_stock_transaction': 1,
        'duplicate_stock_transaction': 1,
      },
    },
  };
}

List<Map<String, dynamic>> _validObservations() => [
  {
    'delivery_date': '2026-01-01',
    'warehouse_token': 'wh-1',
    'product_token': 'pr-1',
    'variant_token': 'vr-1',
    'base_unit_token': 'unit-1',
    'gross_delivered_base_quantity': 10,
    'accepted_return_base_quantity': 2,
    'net_delivered_base_quantity': 8,
    'observed_coverage': true,
    'demand_state': 'observed_positive',
  },
  {
    'delivery_date': '2026-01-02',
    'warehouse_token': 'wh-1',
    'product_token': 'pr-1',
    'variant_token': 'vr-1',
    'base_unit_token': 'unit-1',
    'gross_delivered_base_quantity': 0,
    'accepted_return_base_quantity': 0,
    'net_delivered_base_quantity': 0,
    'observed_coverage': false,
    'demand_state': 'missing',
  },
  {
    'delivery_date': '2026-01-03',
    'warehouse_token': 'wh-1',
    'product_token': 'pr-1',
    'variant_token': 'vr-1',
    'base_unit_token': 'unit-1',
    'gross_delivered_base_quantity': 0,
    'accepted_return_base_quantity': 0,
    'net_delivered_base_quantity': 0,
    'observed_coverage': true,
    'demand_state': 'observed_zero',
  },
];

void main() {
  test('valid historical dataset separates missing and observed zero', () {
    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(),
    );

    expect(dataset.rows, hasLength(3));
    expect(dataset.rows[1]['observed_coverage'], isFalse);
    expect(dataset.rows[1]['data_quality_flags'], contains('MISSING_PERIOD'));
    expect(dataset.rows[2]['observed_coverage'], isTrue);
    expect(dataset.coverage.observedZeroRowCount, 1);
    expect(dataset.coverage.missingRowCount, 1);
  });

  test('duplicate identity/date rows are excluded and reported', () {
    final observations = _validObservations();
    observations.add(Map<String, dynamic>.from(observations.first));

    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(observations: observations),
    );

    expect(dataset.coverage.duplicateRowCount, 1);
    expect(dataset.coverage.dataQualityFlags, contains('DUPLICATE_ROWS'));
  });

  test('negative impossible quantities are excluded', () {
    final observations = _validObservations();
    observations[0]['gross_delivered_base_quantity'] = -1;
    observations[0]['net_delivered_base_quantity'] = -1;

    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(observations: observations),
    );

    expect(dataset.coverage.negativeQuantityRowCount, 1);
  });

  test('missing product or warehouse identity is excluded', () {
    final observations = _validObservations();
    observations[0].remove('product_token');

    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(observations: observations),
    );

    expect(dataset.coverage.missingIdentityRowCount, 1);
  });

  test('unit mismatch is excluded for an identity', () {
    final observations = _validObservations();
    observations[2]['base_unit_token'] = 'unit-2';

    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(observations: observations),
    );

    expect(dataset.coverage.unitMismatchRowCount, 1);
  });

  test('unmatched return exclusions appear in coverage', () {
    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(),
    );

    expect(dataset.coverage.unmatchedReturnRowCount, greaterThanOrEqualTo(2));
    expect(
      dataset.coverage.dataQualityFlags,
      contains('UNMATCHED_RETURNS_EXCLUDED'),
    );
  });

  test('insufficient coverage is explicit', () {
    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(observations: const []),
      minimumObservedRows: 1,
    );

    expect(dataset.coverage.insufficientHistoricalCoverage, isTrue);
    expect(
      dataset.coverage.dataQualityFlags,
      contains('INSUFFICIENT_HISTORICAL_COVERAGE'),
    );
  });

  test('date ordering and gaps remain reportable', () {
    final observations = _validObservations()
      ..removeAt(1)
      ..add({
        'delivery_date': '2026-01-04',
        'warehouse_token': 'wh-1',
        'product_token': 'pr-1',
        'variant_token': 'vr-1',
        'base_unit_token': 'unit-1',
        'gross_delivered_base_quantity': 1,
        'accepted_return_base_quantity': 0,
        'net_delivered_base_quantity': 1,
        'observed_coverage': true,
        'demand_state': 'observed_positive',
      });

    final dataset = HistoricalSalesDatasetValidator.validate(
      payload: _payload(observations: observations),
    );

    expect(dataset.rows.map((row) => row['date']).toList(), [
      '2026-01-01',
      '2026-01-03',
    ]);
    expect(dataset.coverage.negativeQuantityRowCount, 1);
    expect(dataset.coverage.missingDateCount, 1);
  });
}
