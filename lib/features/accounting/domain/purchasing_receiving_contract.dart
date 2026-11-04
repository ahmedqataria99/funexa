import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';

class PurchaseReceiptAccountingLine {
  const PurchaseReceiptAccountingLine({
    required this.purchaseOrderItemId,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.approvedUnitPrice,
  });

  final String purchaseOrderItemId;
  final String itemId;
  final String itemType;
  final double quantity;
  final double approvedUnitPrice;
}

abstract class PurchasingReceiptAccountingSink {
  Future<InventoryValuation> receiveInventoryValueWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double quantity,
    required double unitCost,
    String? productId,
    String? variantId,
    InventoryIdentityKind identityKind = InventoryIdentityKind.base,
    String? unitId,
  });

  Future<String> postPurchaseReceiptWithinTransaction({
    required DatabaseExecutor executor,
    required String purchaseOrderId,
    required String purchaseOrderNumber,
    required String? purchaseRequestId,
    required String receiptId,
    required String receiptNumber,
    required String supplierId,
    required DateTime date,
    required List<PurchaseReceiptAccountingLine> lines,
  });
}
