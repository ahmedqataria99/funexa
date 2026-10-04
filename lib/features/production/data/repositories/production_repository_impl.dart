import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/production/data/datasources/production_local_data_source.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/production/domain/repositories/production_repository.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

class ProductionRepositoryImpl implements ProductionRepository {
  ProductionRepositoryImpl([ProductionLocalDataSource? dataSource])
    : _dataSource = dataSource ?? ProductionLocalDataSource();
  final ProductionLocalDataSource _dataSource;

  @override
  Future<List<Product>> activeProducts() => _dataSource.activeProducts();
  @override
  Future<List<ProductVariant>> activeVariants(String productId) =>
      _dataSource.activeVariants(productId);
  @override
  Future<List<ProductionStage>> activeStages() => _dataSource.activeStages();
  @override
  Future<List<Warehouse>> activeWarehouses() => _dataSource.activeWarehouses();
  @override
  Future<List<ProductionRoute>> routes() => _dataSource.routes();
  @override
  Future<ProductionRoute?> routeForProduct(String productId) =>
      _dataSource.routeForProduct(productId);
  @override
  Future<void> saveRoute(String productId, List<String> stageIds) =>
      _dataSource.saveRoute(productId, stageIds);
  @override
  Future<List<ProductionOrder>> orders([String query = '']) =>
      _dataSource.orders(query);
  @override
  Future<ProductionOrder> getOrder(String id) => _dataSource.getOrder(id);
  @override
  Future<ProductionOrder> createOrder({
    required String productId,
    String? variantId,
    required double plannedQuantity,
    String? notes,
  }) => _dataSource.createOrder(
    productId: productId,
    variantId: variantId,
    plannedQuantity: plannedQuantity,
    notes: notes,
  );
  @override
  Future<void> planOrder(String id) => _dataSource.planOrder(id);
  @override
  Future<void> startOrder(String id) => _dataSource.startOrder(id);
  @override
  Future<void> cancelOrder(String id) => _dataSource.cancelOrder(id);
  @override
  Future<void> startStage(String id) => _dataSource.startStage(id);
  @override
  Future<void> completeStage(String id) => _dataSource.completeStage(id);
  @override
  Future<void> skipStage(String id, String reason) =>
      _dataSource.skipStage(id, reason);
  @override
  Future<List<ProductionMaterialRequirement>> requirements(String orderId) =>
      _dataSource.requirements(orderId);
  @override
  Future<List<ProductionMaterialRecord>> consumptions(String orderId) =>
      _dataSource.consumptions(orderId);
  @override
  Future<List<ProductionWasteRecord>> waste(String orderId) =>
      _dataSource.waste(orderId);
  @override
  Future<List<ProductionOutputRecord>> outputs(String orderId) =>
      _dataSource.outputs(orderId);
  @override
  Future<void> consumeMaterial({
    required String orderId,
    required String rawMaterialId,
    required String warehouseId,
    required double quantity,
    required DateTime date,
    String? notes,
  }) => _dataSource.consumeMaterial(
    orderId: orderId,
    rawMaterialId: rawMaterialId,
    warehouseId: warehouseId,
    quantity: quantity,
    date: date,
    notes: notes,
  );
  @override
  Future<void> recordWaste({
    required String orderId,
    required String rawMaterialId,
    required String warehouseId,
    required double quantity,
    required String reason,
    required DateTime date,
    String? notes,
  }) => _dataSource.recordWaste(
    orderId: orderId,
    rawMaterialId: rawMaterialId,
    warehouseId: warehouseId,
    quantity: quantity,
    reason: reason,
    date: date,
    notes: notes,
  );
  @override
  Future<void> recordOutput({
    required String orderId,
    required String warehouseId,
    required double quantity,
    required DateTime date,
    String? notes,
  }) => _dataSource.recordOutput(
    orderId: orderId,
    warehouseId: warehouseId,
    quantity: quantity,
    date: date,
    notes: notes,
  );
  @override
  Future<List<StockItemOption>> activeRawMaterials() =>
      _dataSource.activeRawMaterials();
}
