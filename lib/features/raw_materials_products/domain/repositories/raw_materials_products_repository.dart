import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';

abstract class RawMaterialsProductsRepository {
  Future<List<Category>> categories([String query = '']);
  Future<List<UnitEntity>> units([String query = '']);
  Future<List<ItemColor>> colors([String query = '']);
  Future<List<RawMaterial>> rawMaterials([
    String query = '',
    String? categoryId,
  ]);
  Future<List<Product>> products([
    String query = '',
    String? categoryId,
    ProductState? state,
  ]);
  Future<List<ProductVariant>> variants(String productId);
  Future<List<ProductAlternative>> getAlternatives(String sourceProductId);
  Future<List<ProductAlternativeCandidate>> getEligibleAlternativeCandidates(
    String sourceProductId,
    String searchQuery,
  );
  Future<void> addAlternative(
    String sourceProductId,
    String targetProductId,
    int priority,
  );
  Future<void> updateAlternativePriority(String alternativeId, int priority);
  Future<void> removeAlternative(String alternativeId);
  Future<List<ProductDimension>> dimensions(String productId);
  Future<List<BomItem>> bom(String productId);
  Future<void> saveCategory(Category value);
  Future<void> saveUnit(UnitEntity value);
  Future<void> saveColor(ItemColor value);
  Future<void> saveRawMaterial(RawMaterial value);
  Future<void> saveProduct(Product value);
  Future<void> saveVariant(ProductVariant value);
  Future<void> saveDimensions(ProductDimension value);
  Future<void> saveBomItem(BomItem value);
  Future<void> deleteBomItem(String id);
  Future<void> setActive(String table, String id, bool active);
}
