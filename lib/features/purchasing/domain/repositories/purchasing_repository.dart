import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

abstract class PurchasingRepository {
  Future<List<Supplier>> suppliers([String query = '']);
  Future<void> saveSupplier(Supplier supplier);
  Future<void> setSupplierActive(String id, bool active);
  Future<List<PurchaseRequest>> requests([String query = '']);
  Future<PurchaseRequest> saveRequest(PurchaseRequest request);
  Future<PurchaseOrder> convertRequestToOrder(
    PurchaseRequest request,
    PurchaseOrder order,
  );
  Future<void> changeRequestStatus(String id, PurchaseRequestStatus status);
  Future<List<PurchaseOrder>> orders([String query = '']);
  Future<PurchaseOrder> saveOrder(PurchaseOrder order);
  Future<void> changeOrderStatus(String id, PurchaseOrderStatus status);
  Future<List<PurchaseReceipt>> receipts(String orderId);
  Future<void> postReceipt({
    required PurchaseOrder order,
    required String warehouseId,
    required DateTime receiptDate,
    required List<PurchasingItem> items,
    String? notes,
    String? operationId,
  });
  Future<List<Warehouse>> activeWarehouses();
  Future<List<StockItemOption>> activeItems();
}
