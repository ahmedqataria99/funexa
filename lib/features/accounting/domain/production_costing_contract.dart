import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';

abstract class ProductionCostingAccountingSink {
  Future<String> receiveProductionCostWithinTransaction({
    required DatabaseExecutor executor,
    required ProductionCostResult result,
  });
}
