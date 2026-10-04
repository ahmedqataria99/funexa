import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:furnexa/features/documents/data/datasources/documents_local_data_source.dart';
import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/entities/document_number.dart';
import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';
import 'package:furnexa/features/documents/services/document_renderer.dart';
import 'package:furnexa/features/documents/services/pdf_document_renderer.dart';

class DocumentsRepositoryImpl implements DocumentsRepository {
  DocumentsRepositoryImpl({
    DocumentsLocalDataSource? dataSource,
    DocumentRenderer? renderer,
  }) : dataSource = dataSource ?? DocumentsLocalDataSource(),
       renderer = renderer ?? PdfDocumentRenderer();

  final DocumentsLocalDataSource dataSource;
  final DocumentRenderer renderer;

  @override
  Future<DocumentNumber> getNextNumber(DocumentType type, {DateTime? date}) =>
      dataSource.nextNumber(type, date: date);
  @override
  Future<DocumentEntity> createDraft({
    required DocumentType type,
    required String title,
    required Map<String, Object?> metadata,
    String? sourceEntityType,
    String? sourceEntityId,
    String? factoryId,
    DocumentLanguage language = DocumentLanguage.arabic,
    DocumentTemplateType templateType = DocumentTemplateType.standard,
  }) => dataSource.createDraft(
    type: type,
    title: title,
    metadata: metadata,
    sourceEntityType: sourceEntityType,
    sourceEntityId: sourceEntityId,
    factoryId: factoryId,
    language: language,
    templateType: templateType,
  );
  @override
  Future<DocumentEntity> post(String documentId) => dataSource.post(documentId);
  @override
  Future<DocumentEntity?> getById(String documentId) =>
      dataSource.getById(documentId);
  @override
  Future<List<DocumentEntity>> history({DocumentType? type}) =>
      dataSource.history(type: type);
  @override
  Future<DocumentEntity> duplicateAsDraft(String documentId) =>
      dataSource.duplicateAsDraft(documentId);
  @override
  Future<List<int>> generatePdf(
    String documentId, {
    DocumentLanguage? language,
    DocumentTemplateType? templateType,
  }) async {
    final source = await dataSource.getById(documentId);
    if (source == null) throw Exception('المستند غير موجود');
    final document = DocumentEntity(
      documentId: source.documentId,
      documentType: source.documentType,
      documentNumber: source.documentNumber,
      issueDate: source.issueDate,
      title: source.title,
      language: language ?? source.language,
      templateType: templateType ?? source.templateType,
      status: source.status,
      sourceEntityType: source.sourceEntityType,
      sourceEntityId: source.sourceEntityId,
      factoryId: source.factoryId,
      createdBy: source.createdBy,
      createdAt: source.createdAt,
      metadata: source.metadata,
    );
    return renderer.render(document);
  }

  @override
  Future<void> printDocument(String documentId) async {
    final bytes = await generatePdf(documentId);
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
  }
}
