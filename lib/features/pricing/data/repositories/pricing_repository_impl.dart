import 'package:furnexa/features/pricing/data/datasources/pricing_local_data_source.dart';
import 'package:furnexa/features/pricing/domain/entities/pricing_entities.dart';
import 'package:furnexa/features/pricing/domain/repositories/pricing_repository.dart';

class PricingRepositoryImpl implements PricingRepository {
  PricingRepositoryImpl([PricingLocalDataSource? dataSource])
    : _dataSource = dataSource ?? PricingLocalDataSource();

  final PricingLocalDataSource _dataSource;

  @override
  Future<List<PriceList>> priceLists([String query = '']) =>
      _dataSource.priceLists(query);

  @override
  Future<void> savePriceList(PriceList value) =>
      _dataSource.savePriceList(value);

  @override
  Future<void> assignCustomerPriceList({
    required String customerId,
    required String priceListId,
  }) => _dataSource.assignCustomerPriceList(
    customerId: customerId,
    priceListId: priceListId,
  );

  @override
  Future<List<ProductPrice>> productPrices({
    String? priceListId,
    String? productId,
    String? variantId,
  }) => _dataSource.productPrices(
    priceListId: priceListId,
    productId: productId,
    variantId: variantId,
  );

  @override
  Future<void> saveProductPrice(ProductPrice value) =>
      _dataSource.saveProductPrice(value);

  @override
  Future<List<CustomerPriceOverride>> customerPrices({
    String? customerId,
    String? productId,
    String? variantId,
  }) => _dataSource.customerPrices(
    customerId: customerId,
    productId: productId,
    variantId: variantId,
  );

  @override
  Future<void> saveCustomerPriceOverride(CustomerPriceOverride value) =>
      _dataSource.saveCustomerPriceOverride(value);

  @override
  Future<List<PriceTier>> quantityTiers({
    String? priceListId,
    String? productId,
    String? variantId,
  }) => _dataSource.quantityTiers(
    priceListId: priceListId,
    productId: productId,
    variantId: variantId,
  );

  @override
  Future<void> saveQuantityTier(PriceTier value) =>
      _dataSource.saveQuantityTier(value);

  @override
  Future<List<DiscountRule>> discountRules({
    String? customerId,
    String? productId,
    String? variantId,
  }) => _dataSource.discountRules(
    customerId: customerId,
    productId: productId,
    variantId: variantId,
  );

  @override
  Future<void> saveDiscountRule(DiscountRule value) =>
      _dataSource.saveDiscountRule(value);

  @override
  Future<List<PriceHistory>> priceHistory({
    String? productId,
    String? variantId,
  }) => _dataSource.priceHistory(productId: productId, variantId: variantId);

  @override
  Future<void> savePriceHistory(PriceHistory value) =>
      _dataSource.savePriceHistory(value);

  @override
  Future<PricingResolution> resolvePrice({
    required String productId,
    String? variantId,
    String? customerId,
    required double quantity,
    DateTime? asOf,
    String? priceListId,
  }) => _dataSource.resolvePrice(
    productId: productId,
    variantId: variantId,
    customerId: customerId,
    quantity: quantity,
    asOf: asOf,
    priceListId: priceListId,
  );
}
