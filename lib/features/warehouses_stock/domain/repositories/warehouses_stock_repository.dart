import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

abstract class WarehousesStockRepository {
  Future<List<Warehouse>> warehouses();
  Future<List<StockItemOption>> activeItems();
  Future<List<StockLine>> stock(
    String? warehouseId, {
    String query = '',
    StockItemType? itemType,
  });
  Future<List<StockLedgerLine>> ledger(
    String warehouseId,
    String itemId,
    StockItemType itemType,
  );
  Future<double> balance(
    String warehouseId,
    String itemId,
    StockItemType itemType,
  );
  Future<void> stockIn({
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  });
  Future<void> stockOut({
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  });
  Future<void> transfer({
    required String sourceWarehouseId,
    required String destinationWarehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  });
  Future<void> adjust({
    required String warehouseId,
    required StockItemOption item,
    required double difference,
    required DateTime date,
    required String reason,
    String? notes,
    String? operationId,
  });
}
