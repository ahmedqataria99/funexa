import 'package:furnexa/features/raw_materials_products/data/datasources/raw_materials_products_local_data_source.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/raw_materials_products/domain/repositories/raw_materials_products_repository.dart';

class RawMaterialsProductsRepositoryImpl
    implements RawMaterialsProductsRepository {
  RawMaterialsProductsRepositoryImpl([
    RawMaterialsProductsLocalDataSource? dataSource,
  ]) : _dataSource = dataSource ?? RawMaterialsProductsLocalDataSource();
  final RawMaterialsProductsLocalDataSource _dataSource;
  @override
  Future<List<Category>> categories([String query = '']) =>
      _dataSource.categories(query);
  @override
  Future<List<UnitEntity>> units([String query = '']) =>
      _dataSource.units(query);
  @override
  Future<List<ItemColor>> colors([String query = '']) =>
      _dataSource.colors(query);
  @override
  Future<List<RawMaterial>> rawMaterials([
    String query = '',
    String? categoryId,
  ]) => _dataSource.rawMaterials(query, categoryId);
  @override
  Future<List<Product>> products([
    String query = '',
    String? categoryId,
    ProductState? state,
  ]) => _dataSource.products(query, categoryId, state);
  @override
  Future<List<ProductVariant>> variants(String productId) =>
      _dataSource.variants(productId);
  @override
  Future<List<ProductAlternative>> getAlternatives(String sourceProductId) =>
      _dataSource.getAlternatives(sourceProductId);
  @override
  Future<List<ProductAlternativeCandidate>> getEligibleAlternativeCandidates(
    String sourceProductId,
    String searchQuery,
  ) => _dataSource.getEligibleAlternativeCandidates(
    sourceProductId,
    searchQuery,
  );
  @override
  Future<void> addAlternative(
    String sourceProductId,
    String targetProductId,
    int priority,
  ) => _dataSource.addAlternative(sourceProductId, targetProductId, priority);
  @override
  Future<void> updateAlternativePriority(String alternativeId, int priority) =>
      _dataSource.updateAlternativePriority(alternativeId, priority);
  @override
  Future<void> removeAlternative(String alternativeId) =>
      _dataSource.removeAlternative(alternativeId);
  @override
  Future<List<ProductDimension>> dimensions(String productId) =>
      _dataSource.dimensions(productId);
  @override
  Future<List<BomItem>> bom(String productId) => _dataSource.bom(productId);
  @override
  Future<void> saveCategory(Category value) => _dataSource.saveCategory(value);
  @override
  Future<void> saveUnit(UnitEntity value) => _dataSource.saveUnit(value);
  @override
  Future<void> saveColor(ItemColor value) => _dataSource.saveColor(value);
  @override
  Future<void> saveRawMaterial(RawMaterial value) =>
      _dataSource.saveRawMaterial(value);
  @override
  Future<void> saveProduct(Product value) => _dataSource.saveProduct(value);
  @override
  Future<void> saveVariant(ProductVariant value) =>
      _dataSource.saveVariant(value);
  @override
  Future<void> saveDimensions(ProductDimension value) =>
      _dataSource.saveDimensions(value);
  @override
  Future<void> saveBomItem(BomItem value) => _dataSource.saveBomItem(value);
  @override
  Future<void> deleteBomItem(String id) => _dataSource.deleteBomItem(id);
  @override
  Future<void> setActive(String table, String id, bool active) =>
      _dataSource.setActive(table, id, active);
}
