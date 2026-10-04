import 'dart:convert';
import 'document_definition.dart';

class DocumentEntity {
  const DocumentEntity({
    required this.documentId,
    required this.documentType,
    required this.documentNumber,
    required this.issueDate,
    required this.title,
    required this.language,
    required this.templateType,
    required this.status,
    required this.sourceEntityType,
    required this.sourceEntityId,
    required this.factoryId,
    required this.createdBy,
    required this.createdAt,
    required this.metadata,
  });

  final String documentId;
  final DocumentType documentType;
  final String documentNumber;
  final DateTime issueDate;
  final String title;
  final DocumentLanguage language;
  final DocumentTemplateType templateType;
  final DocumentStatus status;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final String? factoryId;
  final String? createdBy;
  final DateTime createdAt;
  final Map<String, Object?> metadata;

  String get metadataJson => jsonEncode(metadata);
}
