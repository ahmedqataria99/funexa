import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

abstract class ProductionRepository {
  Future<List<Product>> activeProducts();
  Future<List<ProductVariant>> activeVariants(String productId);
  Future<List<ProductionStage>> activeStages();
  Future<List<Warehouse>> activeWarehouses();
  Future<List<ProductionRoute>> routes();
  Future<ProductionRoute?> routeForProduct(String productId);
  Future<void> saveRoute(String productId, List<String> stageIds);
  Future<List<ProductionOrder>> orders([String query = '']);
  Future<ProductionOrder> getOrder(String id);
  Future<ProductionOrder> createOrder({
    required String productId,
    String? variantId,
    required double plannedQuantity,
    String? notes,
  });
  Future<void> planOrder(String id);
  Future<void> startOrder(String id);
  Future<void> cancelOrder(String id);
  Future<void> startStage(String id);
  Future<void> completeStage(String id);
  Future<void> skipStage(String id, String reason);
  Future<List<ProductionMaterialRequirement>> requirements(String orderId);
  Future<List<ProductionMaterialRecord>> consumptions(String orderId);
  Future<List<ProductionWasteRecord>> waste(String orderId);
  Future<List<ProductionOutputRecord>> outputs(String orderId);
  Future<void> consumeMaterial({
    required String orderId,
    required String rawMaterialId,
    required String warehouseId,
    required double quantity,
    required DateTime date,
    String? notes,
  });
  Future<void> recordWaste({
    required String orderId,
    required String rawMaterialId,
    required String warehouseId,
    required double quantity,
    required String reason,
    required DateTime date,
    String? notes,
  });
  Future<void> recordOutput({
    required String orderId,
    required String warehouseId,
    required double quantity,
    required DateTime date,
    String? notes,
  });
  Future<List<StockItemOption>> activeRawMaterials();
}
