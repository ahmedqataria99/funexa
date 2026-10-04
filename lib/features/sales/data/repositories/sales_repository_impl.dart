import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/sales/domain/repositories/sales_repository.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

class SalesRepositoryImpl implements SalesRepository {
  SalesRepositoryImpl([SalesLocalDataSource? dataSource])
    : _dataSource = dataSource ?? SalesLocalDataSource();
  final SalesLocalDataSource _dataSource;
  @override
  Future<List<Customer>> customers([String query = '']) =>
      _dataSource.customers(query);
  @override
  Future<void> saveCustomer(Customer customer) =>
      _dataSource.saveCustomer(customer);
  @override
  Future<void> setCustomerActive(String id, bool active) =>
      _dataSource.setCustomerActive(id, active);
  @override
  Future<List<Quotation>> quotations([String query = '']) =>
      _dataSource.quotations(query);
  @override
  Future<Quotation> saveQuotation(Quotation quotation) =>
      _dataSource.saveQuotation(quotation);
  @override
  Future<void> changeQuotationStatus(String id, QuotationStatus status) =>
      _dataSource.changeQuotationStatus(id, status);
  @override
  Future<List<SalesOrder>> orders([String query = '']) =>
      _dataSource.orders(query);
  @override
  Future<SalesOrder> saveOrder(SalesOrder order) =>
      _dataSource.saveOrder(order);
  @override
  Future<SalesOrder> convertQuotationToOrder(
    Quotation quotation,
    SalesOrder order,
  ) => _dataSource.convertQuotationToOrder(quotation, order);
  @override
  Future<void> changeOrderStatus(String id, SalesOrderStatus status) =>
      _dataSource.changeOrderStatus(id, status);
  @override
  Future<List<SalesDelivery>> deliveries(String orderId) =>
      _dataSource.deliveries(orderId);
  @override
  Future<SalesDelivery> updateDeliveryDispatch({
    required String deliveryId,
    required DeliveryDispatchStatus status,
    DateTime? dispatchDate,
    String? driverName,
    String? vehicleNumber,
    String? destination,
    String? notes,
  }) => _dataSource.updateDeliveryDispatch(
    deliveryId: deliveryId,
    status: status,
    dispatchDate: dispatchDate,
    driverName: driverName,
    vehicleNumber: vehicleNumber,
    destination: destination,
    notes: notes,
  );
  @override
  Future<void> postDelivery({
    required SalesOrder order,
    required String warehouseId,
    required DateTime deliveryDate,
    required List<SalesItem> items,
    String? notes,
  }) => _dataSource.postDelivery(
    order: order,
    warehouseId: warehouseId,
    deliveryDate: deliveryDate,
    items: items,
    notes: notes,
  );
  @override
  Future<List<Warehouse>> activeWarehouses() => _dataSource.activeWarehouses();
  @override
  Future<List<StockItemOption>> activeItems() => _dataSource.activeItems();
}
