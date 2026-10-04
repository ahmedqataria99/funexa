import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';

class GenerateDocument {
  const GenerateDocument(this.repository);
  final DocumentsRepository repository;
  Future<DocumentEntity> call({
    required DocumentType type,
    required String title,
    required Map<String, Object?> metadata,
    String? sourceEntityType,
    String? sourceEntityId,
    String? factoryId,
    DocumentLanguage language = DocumentLanguage.arabic,
    DocumentTemplateType templateType = DocumentTemplateType.standard,
  }) => repository.createDraft(
    type: type,
    title: title,
    metadata: metadata,
    sourceEntityType: sourceEntityType,
    sourceEntityId: sourceEntityId,
    factoryId: factoryId,
    language: language,
    templateType: templateType,
  );
}
