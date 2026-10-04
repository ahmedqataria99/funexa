import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/purchasing/domain/repositories/purchasing_repository.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

class PurchasingRepositoryImpl implements PurchasingRepository {
  PurchasingRepositoryImpl([PurchasingLocalDataSource? dataSource])
    : _dataSource = dataSource ?? PurchasingLocalDataSource();
  final PurchasingLocalDataSource _dataSource;
  @override
  Future<List<Supplier>> suppliers([String query = '']) =>
      _dataSource.suppliers(query);
  @override
  Future<void> saveSupplier(Supplier supplier) =>
      _dataSource.saveSupplier(supplier);
  @override
  Future<void> setSupplierActive(String id, bool active) =>
      _dataSource.setSupplierActive(id, active);
  @override
  Future<List<PurchaseRequest>> requests([String query = '']) async {
    final requests = await _dataSource.requests(query);
    await FurnexaDatabaseDiagnostics.capture(
      source: 'repository.purchasing.requests',
      purchaseRequestRepositoryRows: requests.length,
      purchaseRequestQuery: query,
    );
    return requests;
  }

  @override
  Future<PurchaseRequest> saveRequest(PurchaseRequest request) =>
      _dataSource.saveRequest(request);
  @override
  Future<void> changeRequestStatus(String id, PurchaseRequestStatus status) =>
      _dataSource.changeRequestStatus(id, status);
  @override
  Future<List<PurchaseOrder>> orders([String query = '']) =>
      _dataSource.orders(query);
  @override
  Future<PurchaseOrder> saveOrder(PurchaseOrder order) =>
      _dataSource.saveOrder(order);
  @override
  Future<PurchaseOrder> convertRequestToOrder(
    PurchaseRequest request,
    PurchaseOrder order,
  ) => _dataSource.convertRequestToOrder(request, order);
  @override
  Future<void> changeOrderStatus(String id, PurchaseOrderStatus status) =>
      _dataSource.changeOrderStatus(id, status);
  @override
  Future<List<PurchaseReceipt>> receipts(String orderId) =>
      _dataSource.receipts(orderId);
  @override
  Future<void> postReceipt({
    required PurchaseOrder order,
    required String warehouseId,
    required DateTime receiptDate,
    required List<PurchasingItem> items,
    String? notes,
    String? operationId,
  }) => _dataSource.postReceipt(
    order: order,
    warehouseId: warehouseId,
    receiptDate: receiptDate,
    items: items,
    notes: notes,
    operationId: operationId,
  );
  @override
  Future<List<Warehouse>> activeWarehouses() => _dataSource.activeWarehouses();
  @override
  Future<List<StockItemOption>> activeItems() => _dataSource.activeItems();
}
