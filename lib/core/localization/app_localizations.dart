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
  String get warehousesStock =>
      locale.languageCode == 'ar' ? 'المخازن والمخزون' : 'Warehouses & stock';
  String get purchasing => locale.languageCode == 'ar'
      ? 'المشتريات والموردين'
      : 'Purchasing & suppliers';
  String get sales =>
      locale.languageCode == 'ar' ? 'المبيعات والعملاء' : 'Sales & customers';
  String get production =>
      locale.languageCode == 'ar' ? 'الإنتاج' : 'Production';
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
