import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

abstract class SalesRepository {
  Future<List<Customer>> customers([String query = '']);
  Future<void> saveCustomer(Customer customer);
  Future<void> setCustomerActive(String id, bool active);
  Future<List<Quotation>> quotations([String query = '']);
  Future<Quotation> saveQuotation(Quotation quotation);
  Future<void> changeQuotationStatus(String id, QuotationStatus status);
  Future<List<SalesOrder>> orders([String query = '']);
  Future<SalesOrder> saveOrder(SalesOrder order);
  Future<SalesOrder> convertQuotationToOrder(
    Quotation quotation,
    SalesOrder order,
  );
  Future<void> changeOrderStatus(String id, SalesOrderStatus status);
  Future<List<SalesDelivery>> deliveries(String orderId);
  Future<SalesDelivery> updateDeliveryDispatch({
    required String deliveryId,
    required DeliveryDispatchStatus status,
    DateTime? dispatchDate,
    String? driverName,
    String? vehicleNumber,
    String? destination,
    String? notes,
  });
  Future<void> postDelivery({
    required SalesOrder order,
    required String warehouseId,
    required DateTime deliveryDate,
    required List<SalesItem> items,
    String? notes,
  });
  Future<List<Warehouse>> activeWarehouses();
  Future<List<StockItemOption>> activeItems();
}
