import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/entities/document_number.dart';

abstract class DocumentsRepository {
  Future<DocumentNumber> getNextNumber(DocumentType type, {DateTime? date});
  Future<DocumentEntity> createDraft({
    required DocumentType type,
    required String title,
    required Map<String, Object?> metadata,
    String? sourceEntityType,
    String? sourceEntityId,
    String? factoryId,
    DocumentLanguage language = DocumentLanguage.arabic,
    DocumentTemplateType templateType = DocumentTemplateType.standard,
  });
  Future<DocumentEntity> post(String documentId);
  Future<DocumentEntity?> getById(String documentId);
  Future<List<DocumentEntity>> history({DocumentType? type});
  Future<DocumentEntity> duplicateAsDraft(String documentId);
  Future<List<int>> generatePdf(
    String documentId, {
    DocumentLanguage? language,
    DocumentTemplateType? templateType,
  });
  Future<void> printDocument(String documentId);
}
