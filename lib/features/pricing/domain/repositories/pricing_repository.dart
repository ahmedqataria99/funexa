import 'package:furnexa/features/pricing/domain/entities/pricing_entities.dart';

abstract class PricingRepository {
  Future<List<PriceList>> priceLists([String query = '']);
  Future<void> savePriceList(PriceList value);
  Future<void> assignCustomerPriceList({
    required String customerId,
    required String priceListId,
  });
  Future<List<ProductPrice>> productPrices({
    String? priceListId,
    String? productId,
    String? variantId,
  });
  Future<void> saveProductPrice(ProductPrice value);
  Future<List<CustomerPriceOverride>> customerPrices({
    String? customerId,
    String? productId,
    String? variantId,
  });
  Future<void> saveCustomerPriceOverride(CustomerPriceOverride value);
  Future<List<PriceTier>> quantityTiers({
    String? priceListId,
    String? productId,
    String? variantId,
  });
  Future<void> saveQuantityTier(PriceTier value);
  Future<List<DiscountRule>> discountRules({
    String? customerId,
    String? productId,
    String? variantId,
  });
  Future<void> saveDiscountRule(DiscountRule value);
  Future<List<PriceHistory>> priceHistory({
    String? productId,
    String? variantId,
  });
  Future<void> savePriceHistory(PriceHistory value);
  Future<PricingResolution> resolvePrice({
    required String productId,
    String? variantId,
    String? customerId,
    required double quantity,
    DateTime? asOf,
    String? priceListId,
  });
}
