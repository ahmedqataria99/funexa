import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [Locale('ar'), Locale('en')];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get appTitle => 'Furnexa ERP';

  String get coreReadyMessage => locale.languageCode == 'ar'
      ? 'تم تهيئة أساس التطبيق بنجاح.'
      : 'Core foundation initialized successfully.';

  String get accounting =>
      locale.languageCode == 'ar' ? 'المحاسبة' : 'Accounting';
  String get chartOfAccounts =>
      locale.languageCode == 'ar' ? 'دليل الحسابات' : 'Chart of Accounts';
  String get cashboxes => locale.languageCode == 'ar' ? 'الخزائن' : 'Cashboxes';
  String get bankAccounts =>
      locale.languageCode == 'ar' ? 'الحسابات البنكية' : 'Bank Accounts';
  String get journalEntries =>
      locale.languageCode == 'ar' ? 'القيود اليومية' : 'Journal Entries';
  String get customerLedger =>
      locale.languageCode == 'ar' ? 'دفتر العملاء' : 'Customer Ledger';
  String get supplierLedger =>
      locale.languageCode == 'ar' ? 'دفتر الموردين' : 'Supplier Ledger';
  String get trialBalance =>
      locale.languageCode == 'ar' ? 'ميزان المراجعة' : 'Trial Balance';
  String get incomeStatement =>
      locale.languageCode == 'ar' ? 'قائمة الدخل' : 'Income Statement';
  String get balanceSheet =>
      locale.languageCode == 'ar' ? 'الميزانية العمومية' : 'Balance Sheet';
  String get accountingPeriods =>
      locale.languageCode == 'ar' ? 'الفترات المحاسبية' : 'Accounting Periods';
  String get notifications =>
      locale.languageCode == 'ar' ? 'الإشعارات' : 'Notifications';
  String get allNotifications => locale.languageCode == 'ar' ? 'الكل' : 'All';
  String get unreadNotifications =>
      locale.languageCode == 'ar' ? 'غير مقروءة' : 'Unread';
  String get notificationAlerts =>
      locale.languageCode == 'ar' ? 'تنبيهات' : 'Alerts';
  String get markAllNotificationsRead =>
      locale.languageCode == 'ar' ? 'تحديد الكل كمقروء' : 'Mark all as read';
  String get markNotificationRead =>
      locale.languageCode == 'ar' ? 'تحديد كمقروء' : 'Mark as read';
  String get markNotificationUnread =>
      locale.languageCode == 'ar' ? 'تحديد كغير مقروء' : 'Mark as unread';
  String get archiveNotification =>
      locale.languageCode == 'ar' ? 'أرشفة' : 'Archive';
  String get noNotifications =>
      locale.languageCode == 'ar' ? 'لا توجد إشعارات' : 'No notifications';

  String get globalSearch =>
      locale.languageCode == 'ar' ? 'البحث العام' : 'Global search';
  String get globalSearchHint => locale.languageCode == 'ar'
      ? 'ابحث عن منتج، عميل، مورد، أمر بيع...'
      : 'Search for a product, customer, supplier, sales order...';
  String get searchStart =>
      locale.languageCode == 'ar' ? 'ابدأ البحث' : 'Start searching';
  String get searchStartDescription => locale.languageCode == 'ar'
      ? 'اكتب كلمة أو رقمًا للوصول السريع إلى بياناتك.'
      : 'Type a name or number to quickly find your data.';
  String get noSearchResults => locale.languageCode == 'ar'
      ? 'لم يتم العثور على نتائج'
      : 'No results found';
  String searchNoResultsFor(String query) => locale.languageCode == 'ar'
      ? 'لم يتم العثور على نتائج لـ «$query»'
      : 'No results found for "$query"';
  String get retrySearch =>
      locale.languageCode == 'ar' ? 'إعادة المحاولة' : 'Retry';
  String get clearSearch => locale.languageCode == 'ar' ? 'مسح' : 'Clear';
  String get clearRecentSearches => locale.languageCode == 'ar'
      ? 'مسح عمليات البحث الأخيرة'
      : 'Clear recent searches';
  String get recentSearches =>
      locale.languageCode == 'ar' ? 'عمليات البحث الأخيرة' : 'Recent searches';
  String get viewAll => locale.languageCode == 'ar' ? 'عرض الكل' : 'View all';
  String get searchFailed => locale.languageCode == 'ar'
      ? 'تعذر تنفيذ البحث. حاول مرة أخرى.'
      : 'Search failed. Please try again.';
  String get allSearchCategories =>
      locale.languageCode == 'ar' ? 'الكل' : 'All';
  String get searchProducts =>
      locale.languageCode == 'ar' ? 'المنتجات' : 'Products';
  String get searchCustomers =>
      locale.languageCode == 'ar' ? 'العملاء' : 'Customers';
  String get searchSales => locale.languageCode == 'ar' ? 'المبيعات' : 'Sales';
  String get searchProduction =>
      locale.languageCode == 'ar' ? 'الإنتاج' : 'Production';
  String get searchWorkers =>
      locale.languageCode == 'ar' ? 'العاملون' : 'Workers';
  String get searchInventory =>
      locale.languageCode == 'ar' ? 'المخزون' : 'Inventory';
  String get searchFactory =>
      locale.languageCode == 'ar' ? 'هيكل المصنع' : 'Factory';

  String get backupRestore => locale.languageCode == 'ar'
      ? 'النسخ الاحتياطي والاستعادة'
      : 'Backup & Restore';
  String get backupRestoreDescription => locale.languageCode == 'ar'
      ? 'إدارة نسخ بيانات Furnexa المحلية بأمان.'
      : 'Manage your local Furnexa backups safely.';
  String get backupSection =>
      locale.languageCode == 'ar' ? 'النسخ الاحتياطي' : 'Backup';
  String get restoreSection =>
      locale.languageCode == 'ar' ? 'الاستعادة' : 'Restore';
  String get backupHistory =>
      locale.languageCode == 'ar' ? 'سجل النسخ الاحتياطية' : 'Backup history';
  String get createBackup =>
      locale.languageCode == 'ar' ? 'إنشاء نسخة احتياطية' : 'Create backup';
  String get createBackupDescription => locale.languageCode == 'ar'
      ? 'احمِ بيانات نظامك بإنشاء نسخة احتياطية محلية.'
      : 'Protect your ERP data by creating a local backup.';
  String get noBackupYet => locale.languageCode == 'ar'
      ? 'لم يتم إنشاء نسخة احتياطية بعد'
      : 'No backup has been created yet';
  String get restoreBackup =>
      locale.languageCode == 'ar' ? 'استعادة نسخة احتياطية' : 'Restore backup';
  String get restoreBackupDescription => locale.languageCode == 'ar'
      ? 'اختر نسخة بصيغة .furnexa لاستعادة قاعدة بيانات النظام.'
      : 'Select a .furnexa backup to restore the ERP database.';
  String get currentDataWillBeReplaced => locale.languageCode == 'ar'
      ? 'ستستبدل هذه العملية جميع بيانات النظام الحالية بالبيانات الموجودة في النسخة الاحتياطية.'
      : 'This will replace all current system data with the data in the backup.';
  String get safetyBackupWillBeCreated => locale.languageCode == 'ar'
      ? 'سيتم إنشاء نسخة أمان من قاعدة البيانات الحالية قبل الاستعادة.'
      : 'A safety backup of the current database will be created before restore.';
  String get createSafetyBackupAndRestore => locale.languageCode == 'ar'
      ? 'إنشاء نسخة أمان والاستعادة'
      : 'Create safety backup & restore';
  String get cancel => locale.languageCode == 'ar' ? 'إلغاء' : 'Cancel';
  String get chooseBackup =>
      locale.languageCode == 'ar' ? 'اختيار نسخة' : 'Choose backup';
  String get chooseDestination =>
      locale.languageCode == 'ar' ? 'اختيار مكان الحفظ' : 'Choose destination';
  String get validBackup =>
      locale.languageCode == 'ar' ? 'نسخة احتياطية صالحة' : 'Valid backup';
  String get invalidBackup => locale.languageCode == 'ar'
      ? 'نسخة احتياطية غير صالحة'
      : 'Invalid backup';
  String get validationStatus =>
      locale.languageCode == 'ar' ? 'حالة التحقق' : 'Validation status';
  String get factoryName => locale.languageCode == 'ar' ? 'المصنع' : 'Factory';
  String get factoryCode =>
      locale.languageCode == 'ar' ? 'رمز المصنع' : 'Factory code';
  String get warehousePurpose =>
      locale.languageCode == 'ar' ? 'غرض المخزن' : 'Warehouse purpose';
  String get sellableWarehousePurpose =>
      locale.languageCode == 'ar' ? 'متاح للبيع والإنتاج' : 'Sellable';
  String get quarantineWarehousePurpose =>
      locale.languageCode == 'ar' ? 'حجر' : 'Quarantine';
  String get reworkWarehousePurpose =>
      locale.languageCode == 'ar' ? 'إعادة العمل' : 'Rework';
  String get damagedWarehousePurpose =>
      locale.languageCode == 'ar' ? 'تالف' : 'Damaged';
  String get warehousePurposeChangeBlocked => locale.languageCode == 'ar'
      ? 'لا يمكن تغيير غرض المخزن طالما يحتوي على مخزون أو قيمة مخزنية. انقل المخزون أو أزله أولاً.'
      : 'Cannot change warehouse purpose while it contains stock or inventory value. Move or clear all stock first.';
  String get backupDate =>
      locale.languageCode == 'ar' ? 'تاريخ النسخة' : 'Backup date';
  String get appVersion =>
      locale.languageCode == 'ar' ? 'إصدار التطبيق' : 'App version';
  String get databaseVersion =>
      locale.languageCode == 'ar' ? 'إصدار قاعدة البيانات' : 'Database version';
  String get backupFormatVersion =>
      locale.languageCode == 'ar' ? 'إصدار الصيغة' : 'Format version';
  String get records => locale.languageCode == 'ar' ? 'السجلات' : 'Records';
  String get fileName =>
      locale.languageCode == 'ar' ? 'اسم الملف' : 'File name';
  String get status => locale.languageCode == 'ar' ? 'الحالة' : 'Status';
  String get backupCreatedSuccessfully => locale.languageCode == 'ar'
      ? 'تم إنشاء النسخة الاحتياطية بنجاح.'
      : 'Backup created successfully.';
  String get backupRestoredSuccessfully => locale.languageCode == 'ar'
      ? 'تمت استعادة النسخة الاحتياطية بنجاح.'
      : 'Backup restored successfully.';
  String get backupCreationFailed => locale.languageCode == 'ar'
      ? 'تعذر إنشاء النسخة الاحتياطية.'
      : 'Unable to create the backup.';
  String get backupRestoreFailed => locale.languageCode == 'ar'
      ? 'تعذر استعادة النسخة الاحتياطية.'
      : 'Unable to restore the backup.';
  String get noBackupHistory => locale.languageCode == 'ar'
      ? 'لا توجد نسخ احتياطية حتى الآن'
      : 'No backups yet';
  String get noBackupHistoryDescription => locale.languageCode == 'ar'
      ? 'أنشئ أول نسخة احتياطية لحماية بيانات المصنع.'
      : 'Create your first backup to protect factory data.';
  String get fileUnavailable =>
      locale.languageCode == 'ar' ? 'الملف غير متاح' : 'File unavailable';
  String get backupInProgress => locale.languageCode == 'ar'
      ? 'جارٍ إنشاء النسخة...'
      : 'Creating backup...';
  String get restoreInProgress => locale.languageCode == 'ar'
      ? 'جارٍ استعادة النسخة...'
      : 'Restoring backup...';
  String get retry => locale.languageCode == 'ar' ? 'إعادة المحاولة' : 'Retry';
  String get chooseAnotherFile =>
      locale.languageCode == 'ar' ? 'اختيار ملف آخر' : 'Choose another file';

  String get home => locale.languageCode == 'ar' ? 'الرئيسية' : 'Home';
  String get search => locale.languageCode == 'ar' ? 'بحث' : 'Search';
  String get username =>
      locale.languageCode == 'ar' ? 'اسم المستخدم' : 'Username';
  String get password =>
      locale.languageCode == 'ar' ? 'كلمة المرور' : 'Password';
  String get login => locale.languageCode == 'ar' ? 'دخول' : 'Login';
  String get setupAdministrator => locale.languageCode == 'ar'
      ? 'إعداد مدير النظام'
      : 'Set up system administrator';
  String get confirmPassword =>
      locale.languageCode == 'ar' ? 'تأكيد كلمة المرور' : 'Confirm password';
  String get setupAdmin =>
      locale.languageCode == 'ar' ? 'إعداد الحساب' : 'Set up account';
  String get passwordMismatch => locale.languageCode == 'ar'
      ? 'كلمتا المرور غير متطابقتين'
      : 'Passwords do not match';
  String get initialAdminPasswordTooShort => locale.languageCode == 'ar'
      ? 'يجب أن تتكون كلمة مرور مدير النظام من 12 حرفًا على الأقل'
      : 'The system administrator password must be at least 12 characters';
  String get loggingIn => locale.languageCode == 'ar'
      ? 'جارٍ التحقق...'
      : 'Checking credentials...';
  String get invalidCredentials => locale.languageCode == 'ar'
      ? 'اسم المستخدم أو كلمة المرور غير صحيحة'
      : 'Invalid username or password';
  String get theme => locale.languageCode == 'ar' ? 'المظهر' : 'Theme';
  String get light => locale.languageCode == 'ar' ? 'فاتح' : 'Light';
  String get dark => locale.languageCode == 'ar' ? 'داكن' : 'Dark';
  String get language => locale.languageCode == 'ar' ? 'اللغة' : 'Language';
  String get arabic => locale.languageCode == 'ar' ? 'العربية' : 'Arabic';
  String get english => locale.languageCode == 'ar' ? 'الإنجليزية' : 'English';
  String get user => locale.languageCode == 'ar' ? 'المستخدم' : 'User';
  String get role => locale.languageCode == 'ar' ? 'الدور' : 'Role';
  String get logout => locale.languageCode == 'ar' ? 'تسجيل الخروج' : 'Log out';
  String get expandSidebar =>
      locale.languageCode == 'ar' ? 'توسيع القائمة' : 'Expand sidebar';
  String get collapseSidebar =>
      locale.languageCode == 'ar' ? 'طي القائمة' : 'Collapse sidebar';
  String get dashboard =>
      locale.languageCode == 'ar' ? 'لوحة التشغيل' : 'Dashboard';
  String get factoryStructure =>
      locale.languageCode == 'ar' ? 'هيكل المصنع' : 'Factory structure';
  String get products => locale.languageCode == 'ar' ? 'الأصناف' : 'Products';
  String get bomQuantityInvalid => locale.languageCode == 'ar'
      ? 'أدخل كمية رقمية محدودة وأكبر من صفر.'
      : 'Enter a finite numeric quantity greater than zero.';
  String get bomDuplicateComponent => locale.languageCode == 'ar'
      ? 'هذه الخامة مضافة بالفعل إلى مكونات المنتج.'
      : 'This raw material is already included in the product BOM.';
  String get bomMaterialUnavailable => locale.languageCode == 'ar'
      ? 'الخامة أو المنتج غير متاح. حدّث البيانات وحاول مرة أخرى.'
      : 'The raw material or product is unavailable. Refresh and try again.';
  String get bomComponentSaved => locale.languageCode == 'ar'
      ? 'تم حفظ مكون المنتج.'
      : 'Product component saved.';
  String get bomComponentDeleted => locale.languageCode == 'ar'
      ? 'تم حذف مكون المنتج.'
      : 'Product component deleted.';
  String get bomComponentDeleteTitle => locale.languageCode == 'ar'
      ? 'حذف مكون المنتج'
      : 'Delete product component';
  String bomComponentDeleteConfirmation(String name) =>
      locale.languageCode == 'ar'
      ? 'هل تريد حذف $name من مكونات هذا المنتج؟'
      : 'Remove $name from this product BOM?';
  String get deleteBomComponent =>
      locale.languageCode == 'ar' ? 'حذف المكون' : 'Delete component';
  String get rawMaterialUnitChangeBlocked => locale.languageCode == 'ar'
      ? 'لا يمكن تغيير الوحدة الأساسية للخامة لأن أمر إنتاج غير مكتمل يستخدم هذه الخامة.'
      : 'The base unit cannot be changed because an unfinished production order '
            'uses this raw material.';
  String get warehousesStock =>
      locale.languageCode == 'ar' ? 'المخازن والمخزون' : 'Warehouses & stock';
  String get purchasing => locale.languageCode == 'ar'
      ? 'المشتريات والموردين'
      : 'Purchasing & suppliers';
  String get sales =>
      locale.languageCode == 'ar' ? 'المبيعات والعملاء' : 'Sales & customers';
  String get salesReturns =>
      locale.languageCode == 'ar' ? 'مرتجعات المبيعات' : 'Sales Returns';
  String get salesReturnsDescription => locale.languageCode == 'ar'
      ? 'استلام المرتجعات وفحصها واعتماد الكميات المقبولة.'
      : 'Receive, inspect, and approve returned goods.';
  String get purchaseReturns =>
      locale.languageCode == 'ar' ? 'مرتجعات المشتريات' : 'Purchase Returns';
  String get purchaseReturnsDescription => locale.languageCode == 'ar'
      ? 'استلام وفحص المرتجع واعتماده ثم تسليمه للمورد.'
      : 'Receive, inspect, approve, and hand returned goods to the supplier.';
  String get createPurchaseReturn => locale.languageCode == 'ar'
      ? 'إنشاء مردود مشتريات'
      : 'Create Purchase Return';
  String get purchaseReturnReference =>
      locale.languageCode == 'ar' ? 'مرجع المرتجع' : 'Return reference';
  String get supplierLabel =>
      locale.languageCode == 'ar' ? 'المورد' : 'Supplier';
  String get allSuppliers =>
      locale.languageCode == 'ar' ? 'كل الموردين' : 'All suppliers';
  String get originalPurchaseOrder => locale.languageCode == 'ar'
      ? 'أمر الشراء الأصلي'
      : 'Original purchase order';
  String get purchaseReceiptSource =>
      locale.languageCode == 'ar' ? 'إيصال الشراء' : 'Purchase receipt';
  String get sourceWarehouse =>
      locale.languageCode == 'ar' ? 'مخزن المصدر' : 'Source warehouse';
  String get physicalStockQuantity =>
      locale.languageCode == 'ar' ? 'المخزون الفعلي' : 'Physical stock';
  String get reservedStockQuantity =>
      locale.languageCode == 'ar' ? 'المحجوز للتسليم' : 'Reserved for delivery';
  String get availableStockQuantity =>
      locale.languageCode == 'ar' ? 'المتاح للحجز' : 'Available to reserve';
  String get noAvailableDeliveryStock => locale.languageCode == 'ar'
      ? 'لا توجد كمية متاحة للحجز في هذا المخزن.'
      : 'No quantity is available to reserve in this warehouse.';
  String get deliveryWarehouseUnavailable => locale.languageCode == 'ar'
      ? 'اختر مخزناً نشطاً صالحاً للبيع.'
      : 'Choose an active sellable warehouse.';
  String get deliveryInsufficientAvailableStock => locale.languageCode == 'ar'
      ? 'الكمية المطلوبة تتجاوز المتاح بعد الحجوزات في هذا المخزن.'
      : 'The requested quantity exceeds this warehouse’s unreserved stock.';
  String get deliveryReservationMissing => locale.languageCode == 'ar'
      ? 'حجز التسليم غير صالح أو تغير. حدّث القائمة وحاول مجدداً.'
      : 'The delivery reservation is invalid or changed. Refresh and retry.';
  String get deliveryPhysicalStockInsufficient => locale.languageCode == 'ar'
      ? 'المخزون الفعلي أقل من الكمية المحجوزة. راجع حركات المخزون.'
      : 'Physical stock is below the reserved quantity. Review stock movements.';
  String get deliveryCancellationAfterDispatch => locale.languageCode == 'ar'
      ? 'لا يمكن إلغاء تسليم تم شحنه أو نقله. سجّل مرتجعاً أو عكساً للمخزون.'
      : 'A dispatched delivery cannot be cancelled. Record a return or stock reversal.';
  String get deliveryInvalidTransition => locale.languageCode == 'ar'
      ? 'انتقال حالة التسليم غير صالح. حدّث القائمة وحاول مجدداً.'
      : 'This delivery status transition is not valid. Refresh and retry.';
  String get deliveryActionFailed => locale.languageCode == 'ar'
      ? 'تعذر تنفيذ إجراء التسليم. تحقق من المخزون والحجوزات ثم أعد المحاولة.'
      : 'Delivery action failed. Check stock and reservations, then retry.';
  String get salesDeliveries =>
      locale.languageCode == 'ar' ? 'التسليمات' : 'Deliveries';
  String get salesOrderDetails =>
      locale.languageCode == 'ar' ? 'تفاصيل أمر البيع' : 'Sales order details';
  String get editSalesPrice =>
      locale.languageCode == 'ar' ? 'تعديل سعر البيع' : 'Edit selling price';
  String get newSalesUnitPrice =>
      locale.languageCode == 'ar' ? 'سعر الوحدة الجديد' : 'New unit price';
  String get salesPriceChanged => locale.languageCode == 'ar'
      ? 'تم تحديث السعر المحفوظ لأمر البيع.'
      : 'The saved sales-order price was updated.';
  String get salesPriceChangeFailed => locale.languageCode == 'ar'
      ? 'تعذر تعديل السعر. لا يمكن تغيير الأسعار بعد التسليم أو الفوترة.'
      : 'Price could not be changed. Prices are locked after delivery or invoicing.';
  String get savedUnitSellingPrice =>
      locale.languageCode == 'ar' ? 'سعر البيع المحفوظ' : 'Saved unit price';
  String get salesSubtotalLabel =>
      locale.languageCode == 'ar' ? 'المجموع الفرعي' : 'Subtotal';
  String get salesDiscountLabel =>
      locale.languageCode == 'ar' ? 'الخصم' : 'Discount';
  String get salesTaxLabel => locale.languageCode == 'ar' ? 'الضريبة' : 'Tax';
  String get issueSalesInvoice =>
      locale.languageCode == 'ar' ? 'إصدار فاتورة' : 'Issue invoice';
  String get invoiceQuantity =>
      locale.languageCode == 'ar' ? 'كمية الفاتورة' : 'Invoice quantity';
  String get invoiceDiscount =>
      locale.languageCode == 'ar' ? 'خصم الفاتورة' : 'Invoice discount';
  String get invoiceTotal =>
      locale.languageCode == 'ar' ? 'إجمالي الفاتورة' : 'Invoice total';
  String get invoiceQuantityInvalid => locale.languageCode == 'ar'
      ? 'أدخل كمية موجبة لا تتجاوز المتبقي غير المفوتر.'
      : 'Enter a positive quantity no greater than the uninvoiced balance.';
  String get invoiceIssued => locale.languageCode == 'ar'
      ? 'تم إصدار الفاتورة باستخدام أسعار أمر البيع المحفوظة.'
      : 'Invoice issued using the saved sales-order prices.';
  String get invoiceIssueFailed => locale.languageCode == 'ar'
      ? 'تعذر إصدار الفاتورة. تحقق من الصلاحيات والبيانات ثم أعد المحاولة.'
      : 'Could not issue the invoice. Check permissions and values, then retry.';
  String get noSalesDeliveries => locale.languageCode == 'ar'
      ? 'لا توجد تسليمات مسجلة لأمر البيع هذا.'
      : 'No deliveries have been recorded for this sales order.';
  String get deliveryReservedNotice => locale.languageCode == 'ar'
      ? 'تم حجز كمية التسليم دون خصمها من المخزون.'
      : 'Delivery quantity reserved without deducting physical stock.';
  String get deliveryPending =>
      locale.languageCode == 'ar' ? 'قيد التجهيز' : 'Pending';
  String get deliveryDispatched =>
      locale.languageCode == 'ar' ? 'تم الشحن' : 'Dispatched';
  String get deliveryInTransit =>
      locale.languageCode == 'ar' ? 'في الطريق' : 'In transit';
  String get deliveryDelivered =>
      locale.languageCode == 'ar' ? 'تم التسليم' : 'Delivered';
  String get deliveryCancelled =>
      locale.languageCode == 'ar' ? 'ملغى' : 'Cancelled';
  String get dispatchDelivery =>
      locale.languageCode == 'ar' ? 'شحن التسليم' : 'Dispatch delivery';
  String get markDeliveryInTransit =>
      locale.languageCode == 'ar' ? 'بدء النقل' : 'Mark in transit';
  String get confirmDeliveryCompletion => locale.languageCode == 'ar'
      ? 'تأكيد استلام العميل للتسليم'
      : 'Confirm delivery was received';
  String get cancelPendingDelivery => locale.languageCode == 'ar'
      ? 'إلغاء الحجز والتسليم'
      : 'Cancel pending delivery';
  String get confirmDeliveryQuestion => locale.languageCode == 'ar'
      ? 'سيتم خصم الكمية المحجوزة من المخزون وتسجيل تكلفة البضاعة. هل تم التسليم فعلياً؟'
      : 'This will deduct the reservation and post cost of goods. Was it physically delivered?';
  String get deliveryStockLoading => locale.languageCode == 'ar'
      ? 'جارٍ تحديث المخزون والحجوزات…'
      : 'Refreshing stock and reservations…';
  String get deliveryAvailabilityFailed => locale.languageCode == 'ar'
      ? 'تعذر تحميل التوفر. تحقق من صلاحية المخزن ثم أعد المحاولة.'
      : 'Could not load availability. Check warehouse access and retry.';
  String get reserveDelivery =>
      locale.languageCode == 'ar' ? 'حجز التسليم' : 'Reserve delivery';
  String get deliveryQuantityExceedsAvailable => locale.languageCode == 'ar'
      ? 'الكمية تتجاوز المتاح أو المتبقي من أمر البيع.'
      : 'Quantity exceeds available stock or the sales order remainder.';
  String get purchaseReturnReason =>
      locale.languageCode == 'ar' ? 'سبب المردود' : 'Return reason';
  String get purchaseReturnNotes =>
      locale.languageCode == 'ar' ? 'ملاحظات المرتجع' : 'Return notes';
  String get requestedReturnQuantity =>
      locale.languageCode == 'ar' ? 'الكمية المطلوبة' : 'Requested quantity';
  String get alreadyReservedQuantity => locale.languageCode == 'ar'
      ? 'محجوز في مرتجعات أخرى'
      : 'Reserved in other returns';
  String get availableReturnQuantity =>
      locale.languageCode == 'ar' ? 'المتاح للمردود' : 'Available to return';
  String get totalReceivedQuantity =>
      locale.languageCode == 'ar' ? 'إجمالي المستلم' : 'Total received';
  String get inspectedQuantity =>
      locale.languageCode == 'ar' ? 'الكمية المفحوصة' : 'Inspected quantity';
  String get quarantinedQuantity =>
      locale.languageCode == 'ar' ? 'الكمية المحجورة' : 'Quarantined quantity';
  String get remainingQuantity =>
      locale.languageCode == 'ar' ? 'الكمية المتبقية' : 'Remaining quantity';
  String get awaitingHandover => locale.languageCode == 'ar'
      ? 'بانتظار تسليم المورد'
      : 'Awaiting supplier handover';
  String get partiallyHandedOver =>
      locale.languageCode == 'ar' ? 'سُلّم جزئياً' : 'Partially handed over';
  String get supplierHandover =>
      locale.languageCode == 'ar' ? 'تسليم المورد' : 'Supplier handover';
  String get handoverReference =>
      locale.languageCode == 'ar' ? 'مرجع التسليم' : 'Handover reference';
  String get handoverDate =>
      locale.languageCode == 'ar' ? 'تاريخ التسليم' : 'Handover date';
  String get recordHandover => locale.languageCode == 'ar'
      ? 'تسجيل التسليم الفعلي'
      : 'Record physical handover';
  String get confirmHandover => locale.languageCode == 'ar'
      ? 'تأكيد تسليم الكميات للمورد وترحيلها؟'
      : 'Confirm supplier handover and post the selected quantities?';
  String get handoverPosted => locale.languageCode == 'ar'
      ? 'تم تسجيل التسليم والترحيل'
      : 'Handover and posting recorded';
  String get handoverOnlyPosting => locale.languageCode == 'ar'
      ? 'يتم ترحيل المخزون والقيد عند التسليم الفعلي فقط.'
      : 'Inventory and accounting post only at physical handover.';
  String get inventoryMovement =>
      locale.languageCode == 'ar' ? 'حركة المخزون' : 'Inventory movement';
  String get accountingJournal =>
      locale.languageCode == 'ar' ? 'القيد المحاسبي' : 'Accounting journal';
  String get physicalReceiptRecorded => locale.languageCode == 'ar'
      ? 'تم تسجيل الاستلام الفعلي'
      : 'Physical receipt recorded';
  String get inspectionPendingForReceipt => locale.languageCode == 'ar'
      ? 'يجب فحص كل بنود إيصال الحجر قبل إكمال الفحص.'
      : 'Inspect every line in this quarantine receipt before completing QC.';
  String get approvalRequiresReceiptAndQc => locale.languageCode == 'ar'
      ? 'يتطلب الاعتماد استلام كامل الكمية وإكمال فحص كل إيصال.'
      : 'Approval requires full physical receipt and completed QC for every receipt.';
  String get decisionNotes =>
      locale.languageCode == 'ar' ? 'ملاحظات القرار' : 'Decision notes';
  String get noPurchaseReturns => locale.languageCode == 'ar'
      ? 'لا توجد مرتجعات مشتريات'
      : 'No Purchase Returns';
  String get noPurchaseReturnsDescription => locale.languageCode == 'ar'
      ? 'ستظهر طلبات مردود المشتريات المسجلة هنا.'
      : 'Recorded Purchase Returns will appear here.';
  String get chooseSupplier =>
      locale.languageCode == 'ar' ? 'اختر المورد' : 'Select supplier';
  String get choosePurchaseOrder =>
      locale.languageCode == 'ar' ? 'اختر أمر شراء' : 'Select purchase order';
  String get chooseQuarantineWarehouse => locale.languageCode == 'ar'
      ? 'اختر مخزن الحجر'
      : 'Select quarantine warehouse';
  String get receiptQuantityInvalid => locale.languageCode == 'ar'
      ? 'كمية الاستلام غير صالحة أو تتجاوز المتبقي.'
      : 'Receipt quantity is invalid or exceeds the remaining amount.';
  String get handoverQuantityInvalid => locale.languageCode == 'ar'
      ? 'كمية التسليم غير صالحة أو تتجاوز المقبول المتبقي.'
      : 'Handover quantity is invalid or exceeds the accepted remainder.';
  String get purchaseReturnCreated => locale.languageCode == 'ar'
      ? 'تم حفظ طلب مردود المشتريات دون ترحيل مخزون أو محاسبة.'
      : 'Purchase Return request saved without inventory or accounting posting.';
  String get purchaseReturnCreationNoPosting => locale.languageCode == 'ar'
      ? 'إنشاء الطلب لا يرحّل المخزون أو الحسابات.'
      : 'Creating this request will not post inventory or accounting.';
  String get searchPurchaseReturns => locale.languageCode == 'ar'
      ? 'ابحث برقم المرتجع أو المورد أو أمر الشراء'
      : 'Search by return, supplier, or purchase order';
  String get singleSourceWarehouseRequired => locale.languageCode == 'ar'
      ? 'يجب أن تأتي بنود المرتجع من مخزن مصدر واحد.'
      : 'All return lines must come from one source warehouse.';
  String get confirm => locale.languageCode == 'ar' ? 'تأكيد' : 'Confirm';
  String get createSalesReturn =>
      locale.languageCode == 'ar' ? 'إنشاء مرتجع' : 'Create Return';
  String get totalReturns =>
      locale.languageCode == 'ar' ? 'إجمالي المرتجعات' : 'Total returns';
  String get pendingReturns =>
      locale.languageCode == 'ar' ? 'قيد المعالجة' : 'Pending';
  String get awaitingReceipt =>
      locale.languageCode == 'ar' ? 'بانتظار الاستلام' : 'Awaiting receipt';
  String get awaitingInspection =>
      locale.languageCode == 'ar' ? 'بانتظار الفحص' : 'Awaiting inspection';
  String get awaitingApproval =>
      locale.languageCode == 'ar' ? 'بانتظار الاعتماد' : 'Awaiting approval';
  String get approvedReturns =>
      locale.languageCode == 'ar' ? 'معتمد' : 'Approved';
  String get returnNumber =>
      locale.languageCode == 'ar' ? 'رقم المرتجع' : 'Return number';
  String get originalSale =>
      locale.languageCode == 'ar' ? 'مستند البيع الأصلي' : 'Original sale';
  String get delivery => locale.languageCode == 'ar' ? 'التسليم' : 'Delivery';
  String get customer => locale.languageCode == 'ar' ? 'العميل' : 'Customer';
  String get returnDate =>
      locale.languageCode == 'ar' ? 'تاريخ المرتجع' : 'Return date';
  String get creationDate =>
      locale.languageCode == 'ar' ? 'تاريخ الإنشاء' : 'Created';
  String get lastUpdated =>
      locale.languageCode == 'ar' ? 'آخر تحديث' : 'Last updated';
  String get totalReturnedQuantity => locale.languageCode == 'ar'
      ? 'إجمالي الكمية المرتجعة'
      : 'Total returned quantity';
  String get searchReturns => locale.languageCode == 'ar'
      ? 'ابحث برقم المرتجع أو العميل أو التسليم'
      : 'Search by return, customer, or delivery';
  String get allStatuses =>
      locale.languageCode == 'ar' ? 'كل الحالات' : 'All statuses';
  String get noSalesReturns => locale.languageCode == 'ar'
      ? 'لا توجد مرتجعات مبيعات'
      : 'No sales returns';
  String get noSalesReturnsDescription => locale.languageCode == 'ar'
      ? 'ستظهر المرتجعات المسجلة هنا.'
      : 'Recorded returns will appear here.';
  String get chooseDeliveredSale => locale.languageCode == 'ar'
      ? 'اختر تسليماً مكتملاً'
      : 'Select a delivered sale';
  String get searchDeliveredSales => locale.languageCode == 'ar'
      ? 'ابحث برقم التسليم أو أمر البيع أو العميل'
      : 'Search delivery, order, or customer';
  String get returnItems =>
      locale.languageCode == 'ar' ? 'بنود المرتجع' : 'Return items';
  String get deliveredQuantity =>
      locale.languageCode == 'ar' ? 'الكمية المسلمة' : 'Delivered quantity';
  String get returnableQuantity =>
      locale.languageCode == 'ar' ? 'المتاح للإرجاع' : 'Returnable quantity';
  String get requestedQuantity =>
      locale.languageCode == 'ar' ? 'كمية الإرجاع' : 'Return quantity';
  String get selectReturnItem => locale.languageCode == 'ar'
      ? 'حدد بنداً واحداً على الأقل'
      : 'Select at least one item';
  String get invalidReturnQuantity => locale.languageCode == 'ar'
      ? 'كمية الإرجاع غير صالحة'
      : 'Invalid return quantity';
  String get returnReason =>
      locale.languageCode == 'ar' ? 'سبب الإرجاع' : 'Return reason';
  String get returnReasonRequired => locale.languageCode == 'ar'
      ? 'أدخل سبب إرجاع البضاعة'
      : 'Enter a reason for the return';
  String get returnDetails =>
      locale.languageCode == 'ar' ? 'تفاصيل المرتجع' : 'Return details';
  String get workflowProgress =>
      locale.languageCode == 'ar' ? 'تقدم الإجراء' : 'Workflow progress';
  String get physicalReceipt =>
      locale.languageCode == 'ar' ? 'الاستلام الفعلي' : 'Physical receipt';
  String get recordReceipt =>
      locale.languageCode == 'ar' ? 'تسجيل الاستلام' : 'Record receipt';
  String get quarantineWarehouse =>
      locale.languageCode == 'ar' ? 'مخزن الحجر' : 'Quarantine warehouse';
  String get destinationWarehouse => locale.languageCode == 'ar'
      ? 'مخزن البضاعة المقبولة'
      : 'Sellable destination';
  String get receivedQuantity =>
      locale.languageCode == 'ar' ? 'المستلم فعلياً' : 'Physically received';
  String get qualityInspection =>
      locale.languageCode == 'ar' ? 'فحص الجودة' : 'Quality inspection';
  String get startInspection =>
      locale.languageCode == 'ar' ? 'تسجيل الفحص' : 'Record inspection';
  String get completeInspection =>
      locale.languageCode == 'ar' ? 'إكمال الفحص' : 'Complete inspection';
  String get acceptedQuantity =>
      locale.languageCode == 'ar' ? 'المقبول' : 'Accepted';
  String get rejectedQuantity =>
      locale.languageCode == 'ar' ? 'المرفوض' : 'Rejected';
  String get reviewApproval =>
      locale.languageCode == 'ar' ? 'مراجعة واعتماد' : 'Review and approval';
  String get approveReturn =>
      locale.languageCode == 'ar' ? 'اعتماد المرتجع' : 'Approve return';
  String get finalResult =>
      locale.languageCode == 'ar' ? 'النتيجة النهائية' : 'Final result';
  String get rejectedRemainQuarantined => locale.languageCode == 'ar'
      ? 'تبقى الكميات المرفوضة في الحجر ولا يتم التخلص منها تلقائياً.'
      : 'Rejected goods remain quarantined; no disposal is performed.';
  String get noReceiptYet => locale.languageCode == 'ar'
      ? 'لم يتم تسجيل استلام فعلي بعد.'
      : 'No physical receipt has been recorded.';
  String get noInspectionYet => locale.languageCode == 'ar'
      ? 'لم يتم تسجيل فحص الجودة بعد.'
      : 'No quality inspection has been recorded.';
  String get pendingStatus =>
      locale.languageCode == 'ar' ? 'قيد الانتظار' : 'Pending';
  String get approvedStatus =>
      locale.languageCode == 'ar' ? 'معتمد' : 'Approved';
  String get rejectedStatus =>
      locale.languageCode == 'ar' ? 'مرفوض' : 'Rejected';
  String get cancelledStatus =>
      locale.languageCode == 'ar' ? 'ملغى' : 'Cancelled';
  String get inProgressStatus =>
      locale.languageCode == 'ar' ? 'قيد الفحص' : 'In progress';
  String get completedStatus =>
      locale.languageCode == 'ar' ? 'مكتمل' : 'Completed';
  String get awaitingReceiptStage =>
      locale.languageCode == 'ar' ? 'الاستلام' : 'Receipt';
  String get inspectionStage =>
      locale.languageCode == 'ar' ? 'الفحص' : 'Inspection';
  String get approvalStage =>
      locale.languageCode == 'ar' ? 'الاعتماد' : 'Approval';
  String get receiptDate =>
      locale.languageCode == 'ar' ? 'تاريخ الاستلام' : 'Receipt date';
  String get saveAndComplete =>
      locale.languageCode == 'ar' ? 'حفظ وإكمال الفحص' : 'Save and complete';
  String get expectedCreditNotShown => locale.languageCode == 'ar'
      ? 'يُنشأ القيد المحاسبي عند الاعتماد.'
      : 'The accounting entry is created on approval.';
  String get accountingEntry =>
      locale.languageCode == 'ar' ? 'القيد المحاسبي' : 'Accounting entry';
  String get stockTransfer =>
      locale.languageCode == 'ar' ? 'تحويل المخزون' : 'Stock transfer';
  String get returnCreated =>
      locale.languageCode == 'ar' ? 'تم إنشاء المرتجع' : 'Return created';
  String get submitReturn =>
      locale.languageCode == 'ar' ? 'إرسال المرتجع' : 'Submit return';
  String get draft => locale.languageCode == 'ar' ? 'مسودة' : 'Draft';
  String get actionFailed =>
      locale.languageCode == 'ar' ? 'تعذر تنفيذ الإجراء' : 'Action failed';
  String get save => locale.languageCode == 'ar' ? 'حفظ' : 'Save';
  String get continueLabel =>
      locale.languageCode == 'ar' ? 'متابعة' : 'Continue';
  String get back => locale.languageCode == 'ar' ? 'رجوع' : 'Back';
  String get production =>
      locale.languageCode == 'ar' ? 'الإنتاج' : 'Production';
  String get productionOutputSellableWarehouseRequired =>
      locale.languageCode == 'ar'
      ? 'يجب استلام المنتج النهائي في مخزن صالح للبيع.'
      : 'Finished goods must be received into a sellable warehouse.';
  String get productionOutputNoEligibleWarehouse => locale.languageCode == 'ar'
      ? 'لا يوجد مخزن نشط صالح للبيع ضمن مصنع المرحلة النهائية ونطاق صلاحيتك.'
      : 'No active sellable warehouse is available in the final-stage factory '
            'and your access scope.';
  String get humanResources =>
      locale.languageCode == 'ar' ? 'الموارد البشرية' : 'Human resources';
  String get usersRoles => locale.languageCode == 'ar'
      ? 'المستخدمون والصلاحيات'
      : 'Users & permissions';
  String get documents =>
      locale.languageCode == 'ar' ? 'المستندات' : 'Documents';
  String get actions => locale.languageCode == 'ar' ? 'الإجراءات' : 'Actions';
  String get selectAll =>
      locale.languageCode == 'ar' ? 'تحديد الكل' : 'Select all';
  String get selected => locale.languageCode == 'ar' ? 'محدد' : 'Selected';
  String get previous => locale.languageCode == 'ar' ? 'السابق' : 'Previous';
  String get next => locale.languageCode == 'ar' ? 'التالي' : 'Next';
  String get first => locale.languageCode == 'ar' ? 'الأول' : 'First';
  String get last => locale.languageCode == 'ar' ? 'الأخير' : 'Last';
  String get rowsPerPage =>
      locale.languageCode == 'ar' ? 'صفوف لكل صفحة' : 'Rows per page';
  String get noResults =>
      locale.languageCode == 'ar' ? 'لا توجد نتائج' : 'No results';
  String get retryTable =>
      locale.languageCode == 'ar' ? 'إعادة المحاولة' : 'Retry';
  String get tableLoadFailed => locale.languageCode == 'ar'
      ? 'تعذر تحميل السجلات'
      : 'Unable to load records';
  String get overview => locale.languageCode == 'ar' ? 'نظرة عامة' : 'Overview';
  String get information =>
      locale.languageCode == 'ar' ? 'المعلومات' : 'Information';
  String get relatedRecords =>
      locale.languageCode == 'ar' ? 'السجلات المرتبطة' : 'Related records';
  String get history => locale.languageCode == 'ar' ? 'السجل' : 'History';
  String get edit => locale.languageCode == 'ar' ? 'تعديل' : 'Edit';
  String get print => locale.languageCode == 'ar' ? 'طباعة' : 'Print';
  String get more => locale.languageCode == 'ar' ? 'المزيد' : 'More';
  String get noHistory =>
      locale.languageCode == 'ar' ? 'لا يوجد سجل' : 'No history';
  String get noRelatedRecords => locale.languageCode == 'ar'
      ? 'لا توجد سجلات مرتبطة'
      : 'No related records';
  String get refresh => locale.languageCode == 'ar' ? 'تحديث' : 'Refresh';
  String get name => locale.languageCode == 'ar' ? 'الاسم' : 'Name';
  String get code => locale.languageCode == 'ar' ? 'الكود' : 'Code';
  String get phone => locale.languageCode == 'ar' ? 'الهاتف' : 'Phone';
  String get email =>
      locale.languageCode == 'ar' ? 'البريد الإلكتروني' : 'Email';
  String get address => locale.languageCode == 'ar' ? 'العنوان' : 'Address';
  String get taxNumber =>
      locale.languageCode == 'ar' ? 'الرقم الضريبي' : 'Tax number';
  String get active => locale.languageCode == 'ar' ? 'نشط' : 'Active';
  String get inactive => locale.languageCode == 'ar' ? 'غير نشط' : 'Inactive';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
