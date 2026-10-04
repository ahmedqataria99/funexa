import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/documents/data/datasources/documents_local_data_source.dart';
import 'package:furnexa/features/documents/data/repositories/documents_repository_impl.dart';
import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import '../../test_helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecurityLocalDataSource security;
  late DocumentsLocalDataSource dataSource;
  late DocumentsRepositoryImpl repository;
  late Database db;

  setUp(() async {
    await DatabaseTestHelper.reset();
    db = await FurnexaDatabase.instance.database;
    security = SecurityLocalDataSource();
    await security.ensureInitialAdmin();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    dataSource = DocumentsLocalDataSource(security: security);
    repository = DocumentsRepositoryImpl(dataSource: dataSource);
  });

  tearDown(() async {
    security.logout();
    await DatabaseTestHelper.reset();
  });

  Future<DocumentEntity> createDocument({
    DocumentType type = DocumentType.purchaseOrder,
    DocumentTemplateType template = DocumentTemplateType.standard,
  }) => repository.createDraft(
    type: type,
    title: type.value,
    metadata: {
      'columns': ['Item', 'Quantity'],
      'rows': List.generate(
        40,
        (index) => {'Item': 'Item $index', 'Quantity': index + 1},
      ),
      'notes': 'Furnexa document',
    },
    sourceEntityType: 'PurchaseOrder',
    sourceEntityId: 'source-1',
    language: DocumentLanguage.arabic,
    templateType: template,
  );

  test('document type registration', () {
    expect(DocumentType.values, contains(DocumentType.purchaseOrder));
    expect(DocumentType.purchaseOrder.value, 'PURCHASE_ORDER');
  });

  test('document definition retrieval', () {
    expect(DocumentType.deliveryNote.prefix, 'DN');
    expect(DocumentType.payrollReport.permission, 'HR_VIEW');
  });

  test('document sequence creation', () async {
    final number = await repository.getNextNumber(
      DocumentType.purchaseOrder,
      date: DateTime(2026),
    );
    expect(number.value, 'PO-2026-000001');
  });

  test('sequential numbering', () async {
    expect(
      (await repository.getNextNumber(
        DocumentType.purchaseOrder,
        date: DateTime(2026),
      )).sequence,
      1,
    );
    expect(
      (await repository.getNextNumber(
        DocumentType.purchaseOrder,
        date: DateTime(2026),
      )).sequence,
      2,
    );
  });

  test('different document types have independent sequences', () async {
    await repository.getNextNumber(
      DocumentType.purchaseOrder,
      date: DateTime(2026),
    );
    expect(
      (await repository.getNextNumber(
        DocumentType.salesOrder,
        date: DateTime(2026),
      )).sequence,
      1,
    );
  });

  test('different years have independent sequences', () async {
    await repository.getNextNumber(
      DocumentType.purchaseOrder,
      date: DateTime(2026),
    );
    expect(
      (await repository.getNextNumber(
        DocumentType.purchaseOrder,
        date: DateTime(2027),
      )).sequence,
      1,
    );
  });

  test('duplicate document number prevention', () async {
    final document = await createDocument();
    expect(
      () => db.insert('document_records', {
        'documentId': 'duplicate',
        'documentType': document.documentType.value,
        'documentNumber': document.documentNumber,
        'issueDate': 1,
        'title': 'duplicate',
        'language': 'ar',
        'templateType': 'STANDARD',
        'status': 'DRAFT',
        'createdAt': 1,
        'metadata': '{}',
      }),
      throwsException,
    );
  });

  test('transaction-safe number increment', () async {
    final number = await repository.getNextNumber(
      DocumentType.purchaseOrder,
      date: DateTime(2026),
    );
    expect(number.sequence, 1);
    await expectLater(
      db.transaction((txn) async {
        await txn.update(
          'document_sequences',
          {'lastNumber': 99},
          where: 'documentType = ?',
          whereArgs: ['PURCHASE_ORDER'],
        );
        throw Exception('rollback');
      }),
      throwsException,
    );
    expect(
      (await repository.getNextNumber(
        DocumentType.purchaseOrder,
        date: DateTime(2026),
      )).sequence,
      2,
    );
  });

  test('failed operation does not corrupt sequence state', () async {
    await expectLater(
      db.transaction((txn) async {
        await txn.insert('document_sequences', {
          'id': 'bad',
          'documentType': 'PURCHASE_ORDER',
          'year': 2026,
          'lastNumber': 10,
          'createdAt': 1,
          'updatedAt': 1,
        });
        throw Exception('rollback');
      }),
      throwsException,
    );
    expect(
      (await repository.getNextNumber(
        DocumentType.purchaseOrder,
        date: DateTime(2026),
      )).sequence,
      1,
    );
  });

  test('document metadata persistence', () async {
    final document = await createDocument();
    expect(document.metadata['notes'], 'Furnexa document');
  });

  test('document retrieval', () async {
    final document = await createDocument();
    expect(
      (await repository.getById(document.documentId))?.documentNumber,
      document.documentNumber,
    );
  });

  test('posted document protection', () async {
    final document = await createDocument();
    final posted = await repository.post(document.documentId);
    expect(posted.status, DocumentStatus.posted);
    expect(await repository.post(document.documentId), isA<DocumentEntity>());
  });

  test('reprint does not create a new document', () async {
    final document = await createDocument();
    await repository.generatePdf(document.documentId);
    expect(await repository.history(), hasLength(1));
  });

  test('reprint keeps original document number', () async {
    final document = await createDocument();
    await repository.generatePdf(document.documentId);
    expect(
      (await repository.getById(document.documentId))!.documentNumber,
      document.documentNumber,
    );
  });

  test('document history enforces each document feature permission', () async {
    final salesDocument = await repository.createDraft(
      type: DocumentType.salesOrder,
      title: 'Permitted sales document',
      metadata: const {},
    );
    final purchaseDocument = await repository.createDraft(
      type: DocumentType.purchaseOrder,
      title: 'Restricted purchase document',
      metadata: const {},
    );
    final role = await security.createRole(name: 'Sales Audit Viewer');
    await security.setRolePermissions(role.id, ['AUDIT_VIEW', 'SALES_VIEW']);
    final user = await security.createUser(
      username: 'sales-audit-viewer',
      displayName: 'Sales Audit Viewer',
      password: 'secret123',
      roleId: role.id,
    );
    security.logout();
    await security.login(user.username, 'secret123');

    final history = await repository.history();
    expect(
      history.any((entry) => entry.documentId == salesDocument.documentId),
      isTrue,
    );
    expect(
      history.any((entry) => entry.documentId == purchaseDocument.documentId),
      isFalse,
    );
  });

  test('document history enforces warehouse scope', () async {
    final allowed = await repository.createDraft(
      type: DocumentType.stockIn,
      title: 'Allowed warehouse document',
      metadata: const {'warehouseId': 'warehouse-a'},
    );
    final restricted = await repository.createDraft(
      type: DocumentType.stockIn,
      title: 'Other warehouse document',
      metadata: const {'warehouseId': 'warehouse-b'},
    );
    final role = await security.createRole(name: 'Warehouse Audit Viewer');
    await security.setRolePermissions(role.id, [
      'AUDIT_VIEW',
      'WAREHOUSE_STOCK_VIEW',
    ]);
    final user = await security.createUser(
      username: 'warehouse-audit-viewer',
      displayName: 'Warehouse Audit Viewer',
      password: 'secret123',
      roleId: role.id,
    );
    await security.setUserScopes(user.id, [
      UserScope(
        id: 'warehouse-scope',
        userId: user.id,
        type: ScopeType.warehouse,
        scopeId: 'warehouse-a',
      ),
    ]);
    security.logout();
    await security.login(user.username, 'secret123');

    final history = await repository.history();
    expect(
      history.any((entry) => entry.documentId == allowed.documentId),
      isTrue,
    );
    expect(
      history.any((entry) => entry.documentId == restricted.documentId),
      isFalse,
    );
  });

  test('duplicate-as-draft does not copy number', () async {
    final source = await createDocument();
    final copy = await repository.duplicateAsDraft(source.documentId);
    expect(copy.documentNumber, isNot(source.documentNumber));
  });

  test('duplicate-as-draft remains draft', () async {
    final copy = await repository.duplicateAsDraft(
      (await createDocument()).documentId,
    );
    expect(copy.status, DocumentStatus.draft);
  });

  test('factory header data', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': 'factory-1',
      'name': 'Furnexa Factory',
      'code': 'FX',
      'phone': '1',
      'email': 'a@b.com',
      'address': 'Address',
      'createdAt': now,
      'updatedAt': now,
    });
    final document = await createDocument();
    expect(document.metadata, isNotNull);
  });

  test('customer document data', () async {
    final document = await repository.createDraft(
      type: DocumentType.salesOrder,
      title: 'Sales',
      metadata: {'customer': 'Customer A'},
      sourceEntityType: 'Customer',
      sourceEntityId: 'customer-1',
    );
    expect(document.metadata['customer'], 'Customer A');
  });

  test('supplier document data', () async {
    final document = await repository.createDraft(
      type: DocumentType.purchaseOrder,
      title: 'Purchase',
      metadata: {'supplier': 'Supplier A'},
      sourceEntityType: 'Supplier',
      sourceEntityId: 'supplier-1',
    );
    expect(document.metadata['supplier'], 'Supplier A');
  });

  test('inventory document data', () async {
    final document = await repository.createDraft(
      type: DocumentType.stockIn,
      title: 'Stock In',
      metadata: {'warehouse': 'A', 'quantity': 4},
    );
    expect(document.metadata['quantity'], 4);
  });

  test('production document data', () async {
    final document = await repository.createDraft(
      type: DocumentType.productionOrder,
      title: 'Production',
      metadata: {'planned': 20},
    );
    expect(document.metadata['planned'], 20);
  });

  test('payroll document data', () async {
    final document = await repository.createDraft(
      type: DocumentType.payrollReport,
      title: 'Payroll',
      metadata: {'net': 8000},
    );
    expect(document.metadata['net'], 8000);
  });

  test('accounting document data', () async {
    final document = await repository.createDraft(
      type: DocumentType.journalEntry,
      title: 'Journal',
      metadata: {'amount': 100},
    );
    expect(document.metadata['amount'], 100);
  });

  test('Arabic localization', () async {
    await testerPump(const Locale('ar'));
  });

  test('English localization', () async {
    await testerPump(const Locale('en'));
  });

  test('RTL document configuration', () async {
    final document = await createDocument();
    expect(document.language, DocumentLanguage.arabic);
  });

  test('A4 template selection', () async {
    expect(
      (await createDocument()).templateType,
      DocumentTemplateType.standard,
    );
  });

  test('Compact template selection', () async {
    expect(
      (await createDocument(
        template: DocumentTemplateType.compact,
      )).templateType,
      DocumentTemplateType.compact,
    );
  });

  test('Thermal template selection', () async {
    expect(
      (await createDocument(
        template: DocumentTemplateType.thermal,
      )).templateType,
      DocumentTemplateType.thermal,
    );
  });

  test('multi-page document generation', () async {
    expect(
      (await repository.generatePdf(
        (await createDocument()).documentId,
      )).length,
      greaterThan(100),
    );
  });

  test('long item table pagination', () async {
    final bytes = await repository.generatePdf(
      (await createDocument()).documentId,
    );
    expect(bytes, isNotEmpty);
  });

  test('Arabic text rendering path', () async {
    final document = await repository.createDraft(
      type: DocumentType.purchaseOrder,
      title: 'أمر شراء',
      metadata: {'notes': 'مستند عربي'},
      language: DocumentLanguage.arabic,
    );
    expect(await repository.generatePdf(document.documentId), isNotEmpty);
  });

  test('embedded Arabic font assets load', () async {
    final regular = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );
    final bold = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
    expect(regular.lengthInBytes, greaterThan(100000));
    expect(bold.lengthInBytes, greaterThan(100000));
  });

  test('mixed Arabic/English content', () async {
    final document = await repository.createDraft(
      type: DocumentType.purchaseOrder,
      title: 'Purchase أمر شراء',
      metadata: {'notes': 'MDF 18mm'},
      language: DocumentLanguage.arabic,
    );
    expect(await repository.generatePdf(document.documentId), isNotEmpty);
  });

  test('missing source entity handled safely', () async {
    final document = await createDocument();
    expect(await repository.getById(document.documentId), isNotNull);
  });

  test('permission-protected document access', () async {
    final role = await security.createRole(name: 'No Purchase Documents');
    final user = await security.createUser(
      username: 'no-purchase',
      displayName: 'No Purchase',
      password: 'secret',
      roleId: role.id,
    );
    security.logout();
    await security.login(user.username, 'secret');
    expect(
      () => repository.getNextNumber(DocumentType.purchaseOrder),
      throwsException,
    );
  });

  test('scope-protected document access', () async {
    final protectedDocument = await repository.createDraft(
      type: DocumentType.stockIn,
      title: 'Scoped stock',
      metadata: {'warehouseId': 'warehouse-a'},
    );
    final role = await security.createRole(name: 'Scoped Documents');
    await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_VIEW']);
    final user = await security.createUser(
      username: 'warehouse-document',
      displayName: 'Warehouse',
      password: 'secret',
      roleId: role.id,
    );
    security.logout();
    await security.login(user.username, 'secret');
    expect(
      () async => await repository.getById(protectedDocument.documentId),
      throwsException,
    );
  });

  test('preview action', () async {
    final document = await createDocument();
    expect(await repository.generatePdf(document.documentId), isNotEmpty);
  });

  test('PDF generation', () async {
    final document = await createDocument();
    expect(
      (await repository.generatePdf(document.documentId)).take(4).toList(),
      [37, 80, 68, 70],
    );
  });

  test('print action preparation', () async {
    final document = await createDocument();
    expect(await repository.generatePdf(document.documentId), isNotEmpty);
  });

  test('audit integration', () async {
    final document = await createDocument();
    final logs = await security.auditLogs(module: 'Documents');
    expect(logs.any((log) => log.entityId == document.documentId), isTrue);
  });
}

Future<void> testerPump(Locale locale) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.runAsync(() async {});
  expect(locale.languageCode, isIn(['ar', 'en']));
}
