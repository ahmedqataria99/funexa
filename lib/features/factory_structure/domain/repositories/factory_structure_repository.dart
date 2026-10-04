import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/factory_structure/domain/entities/workshop.dart';

abstract class FactoryStructureRepository {
  Future<FactoryProfile?> getFactory();
  Future<void> saveFactory(FactoryProfile factory);

  Future<List<Section>> getSections();
  Future<List<Section>> searchSections(String query);
  Future<void> saveSection(Section section);

  Future<List<Workshop>> getWorkshops();
  Future<List<Workshop>> searchWorkshops(String query);
  Future<void> saveWorkshop(Workshop workshop);

  Future<List<ProductionStage>> getProductionStages();
  Future<List<ProductionStage>> searchProductionStages(String query);
  Future<void> saveProductionStage(ProductionStage stage);

  Future<List<Warehouse>> getWarehouses();
  Future<List<Warehouse>> searchWarehouses(String query);
  Future<void> saveWarehouse(Warehouse warehouse);
}
