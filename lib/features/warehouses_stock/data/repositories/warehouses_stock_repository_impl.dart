import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/warehouses_stock/domain/repositories/warehouses_stock_repository.dart';

class WarehousesStockRepositoryImpl implements WarehousesStockRepository {
  WarehousesStockRepositoryImpl([WarehousesStockLocalDataSource? dataSource])
    : _dataSource = dataSource ?? WarehousesStockLocalDataSource();
  final WarehousesStockLocalDataSource _dataSource;
  @override
  Future<List<Warehouse>> warehouses() async {
    final warehouses = await _dataSource.warehouses();
    await FurnexaDatabaseDiagnostics.capture(
      source: 'repository.stock.warehouses',
      stockWarehouseRepositoryRows: warehouses.length,
    );
    return warehouses;
  }
  @override
  Future<List<StockItemOption>> activeItems() => _dataSource.activeItems();
  @override
  Future<List<StockLine>> stock(
    String? warehouseId, {
    String query = '',
    StockItemType? itemType,
  }) async {
    final stock = await _dataSource.stock(
      warehouseId,
      query: query,
      itemType: itemType,
    );
    await FurnexaDatabaseDiagnostics.capture(
      source: 'repository.stock.stock',
      stockRepositoryRows: stock.length,
      warehouseId: warehouseId,
      stockQuery: query,
      stockItemTypeFilter: itemType?.value,
    );
    return stock;
  }
  @override
  Future<List<StockLedgerLine>> ledger(
    String warehouseId,
    String itemId,
    StockItemType itemType,
  ) => _dataSource.ledger(warehouseId, itemId, itemType);
  @override
  Future<double> balance(
    String warehouseId,
    String itemId,
    StockItemType itemType,
  ) => _dataSource.balance(warehouseId, itemId, itemType);
  @override
  Future<void> stockIn({
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) => _dataSource.stockIn(
    warehouseId: warehouseId,
    item: item,
    quantity: quantity,
    date: date,
    reference: reference,
    notes: notes,
    operationId: operationId,
  );
  @override
  Future<void> stockOut({
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) => _dataSource.stockOut(
    warehouseId: warehouseId,
    item: item,
    quantity: quantity,
    date: date,
    reference: reference,
    notes: notes,
    operationId: operationId,
  );
  @override
  Future<void> transfer({
    required String sourceWarehouseId,
    required String destinationWarehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) => _dataSource.transfer(
    sourceWarehouseId: sourceWarehouseId,
    destinationWarehouseId: destinationWarehouseId,
    item: item,
    quantity: quantity,
    date: date,
    reference: reference,
    notes: notes,
    operationId: operationId,
  );
  @override
  Future<void> adjust({
    required String warehouseId,
    required StockItemOption item,
    required double difference,
    required DateTime date,
    required String reason,
    String? notes,
    String? operationId,
  }) => _dataSource.adjust(
    warehouseId: warehouseId,
    item: item,
    difference: difference,
    date: date,
    reason: reason,
    notes: notes,
    operationId: operationId,
  );
}
