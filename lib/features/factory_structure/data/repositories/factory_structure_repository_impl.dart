import 'package:furnexa/features/factory_structure/data/datasources/factory_structure_local_data_source.dart';
import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/factory_structure/domain/entities/workshop.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/features/factory_structure/domain/repositories/factory_structure_repository.dart';

class FactoryStructureRepositoryImpl implements FactoryStructureRepository {
  FactoryStructureRepositoryImpl({FactoryStructureLocalDataSource? dataSource})
      : _dataSource = dataSource ?? FactoryStructureLocalDataSource();

  final FactoryStructureLocalDataSource _dataSource;

  @override
  Future<FactoryProfile?> getFactory() => _dataSource.getFactory();

  @override
  Future<void> saveFactory(FactoryProfile factory) => _dataSource.upsertFactory(factory);

  @override
  Future<List<Section>> getSections() => _dataSource.getSections();

  @override
  Future<List<Section>> searchSections(String query) => _dataSource.searchSections(query);

  @override
  Future<void> saveSection(Section section) => _dataSource.upsertSection(section);

  @override
  Future<List<Workshop>> getWorkshops() => _dataSource.getWorkshops();

  @override
  Future<List<Workshop>> searchWorkshops(String query) => _dataSource.searchWorkshops(query);

  @override
  Future<void> saveWorkshop(Workshop workshop) => _dataSource.upsertWorkshop(workshop);

  @override
  Future<List<ProductionStage>> getProductionStages() => _dataSource.getProductionStages();

  @override
  Future<List<ProductionStage>> searchProductionStages(String query) =>
      _dataSource.searchProductionStages(query);

  @override
  Future<void> saveProductionStage(ProductionStage stage) =>
      _dataSource.upsertProductionStage(stage);

  @override
  Future<List<Warehouse>> getWarehouses() async {
    final warehouses = await _dataSource.getWarehouses();
    await FurnexaDatabaseDiagnostics.capture(
      source: 'repository.factory.getWarehouses',
      factoryWarehouseRepositoryRows: warehouses.length,
    );
    return warehouses;
  }

  @override
  Future<List<Warehouse>> searchWarehouses(String query) async {
    final warehouses = await _dataSource.searchWarehouses(query);
    await FurnexaDatabaseDiagnostics.capture(
      source: 'repository.factory.searchWarehouses',
      factoryWarehouseRepositoryRows: warehouses.length,
      warehouseSearch: query,
    );
    return warehouses;
  }

  @override
  Future<void> saveWarehouse(Warehouse warehouse) => _dataSource.upsertWarehouse(warehouse);
}
