enum DocumentType {
  purchaseRequest,
  purchaseOrder,
  purchaseReceipt,
  quotation,
  salesOrder,
  deliveryNote,
  stockIn,
  stockOut,
  stockTransfer,
  stockAdjustment,
  productionOrder,
  materialConsumptionReport,
  productionCompletionReport,
  attendanceReport,
  payrollReport,
  payslip,
  paymentReceipt,
  supplierPaymentVoucher,
  expenseVoucher,
  journalEntry,
}

enum DocumentTemplateType { standard, compact, thermal }

enum DocumentStatus { draft, posted, cancelled }

enum DocumentLanguage { arabic, english }

extension DocumentTypeValues on DocumentType {
  String get value => switch (this) {
    DocumentType.purchaseRequest => 'PURCHASE_REQUEST',
    DocumentType.purchaseOrder => 'PURCHASE_ORDER',
    DocumentType.purchaseReceipt => 'PURCHASE_RECEIPT',
    DocumentType.quotation => 'QUOTATION',
    DocumentType.salesOrder => 'SALES_ORDER',
    DocumentType.deliveryNote => 'DELIVERY_NOTE',
    DocumentType.stockIn => 'STOCK_IN',
    DocumentType.stockOut => 'STOCK_OUT',
    DocumentType.stockTransfer => 'STOCK_TRANSFER',
    DocumentType.stockAdjustment => 'STOCK_ADJUSTMENT',
    DocumentType.productionOrder => 'PRODUCTION_ORDER',
    DocumentType.materialConsumptionReport => 'MATERIAL_CONSUMPTION_REPORT',
    DocumentType.productionCompletionReport => 'PRODUCTION_COMPLETION_REPORT',
    DocumentType.attendanceReport => 'ATTENDANCE_REPORT',
    DocumentType.payrollReport => 'PAYROLL_REPORT',
    DocumentType.payslip => 'PAYSLIP',
    DocumentType.paymentReceipt => 'PAYMENT_RECEIPT',
    DocumentType.supplierPaymentVoucher => 'SUPPLIER_PAYMENT_VOUCHER',
    DocumentType.expenseVoucher => 'EXPENSE_VOUCHER',
    DocumentType.journalEntry => 'JOURNAL_ENTRY',
  };

  String get prefix => switch (this) {
    DocumentType.purchaseRequest => 'PR',
    DocumentType.purchaseOrder => 'PO',
    DocumentType.purchaseReceipt => 'GRN',
    DocumentType.quotation => 'QT',
    DocumentType.salesOrder => 'SO',
    DocumentType.deliveryNote => 'DN',
    DocumentType.stockIn => 'STI',
    DocumentType.stockOut => 'STO',
    DocumentType.stockTransfer => 'TRF',
    DocumentType.stockAdjustment => 'ADJ',
    DocumentType.productionOrder => 'PROD',
    DocumentType.materialConsumptionReport => 'MC',
    DocumentType.productionCompletionReport => 'PC',
    DocumentType.attendanceReport => 'ATT',
    DocumentType.payrollReport => 'PAY',
    DocumentType.payslip => 'PAYSLIP',
    DocumentType.paymentReceipt => 'RCT',
    DocumentType.supplierPaymentVoucher => 'SPV',
    DocumentType.expenseVoucher => 'EXP',
    DocumentType.journalEntry => 'JE',
  };

  String get permission => switch (this) {
    DocumentType.purchaseRequest ||
    DocumentType.purchaseOrder ||
    DocumentType.purchaseReceipt => 'PURCHASING_VIEW',
    DocumentType.quotation ||
    DocumentType.salesOrder ||
    DocumentType.deliveryNote => 'SALES_VIEW',
    DocumentType.stockIn ||
    DocumentType.stockOut ||
    DocumentType.stockTransfer ||
    DocumentType.stockAdjustment => 'WAREHOUSE_STOCK_VIEW',
    DocumentType.productionOrder ||
    DocumentType.materialConsumptionReport ||
    DocumentType.productionCompletionReport => 'PRODUCTION_VIEW',
    DocumentType.attendanceReport ||
    DocumentType.payrollReport ||
    DocumentType.payslip => 'HR_VIEW',
    DocumentType.paymentReceipt ||
    DocumentType.supplierPaymentVoucher ||
    DocumentType.expenseVoucher ||
    DocumentType.journalEntry => 'ACCOUNTING_VIEW',
  };
}

extension DocumentTemplateValues on DocumentTemplateType {
  String get value => name.toUpperCase();
}

extension DocumentStatusValues on DocumentStatus {
  String get value => name.toUpperCase();
}

extension DocumentLanguageValues on DocumentLanguage {
  String get value => this == DocumentLanguage.arabic ? 'ar' : 'en';
}
