import 'dart:convert';
import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';

class DocumentRecordModel extends DocumentEntity {
  const DocumentRecordModel({
    required super.documentId,
    required super.documentType,
    required super.documentNumber,
    required super.issueDate,
    required super.title,
    required super.language,
    required super.templateType,
    required super.status,
    required super.sourceEntityType,
    required super.sourceEntityId,
    required super.factoryId,
    required super.createdBy,
    required super.createdAt,
    required super.metadata,
  });

  factory DocumentRecordModel.fromMap(Map<String, Object?> row) =>
      DocumentRecordModel(
        documentId: row['documentId'] as String,
        documentType: DocumentType.values.firstWhere(
          (value) => value.value == row['documentType'],
        ),
        documentNumber: row['documentNumber'] as String,
        issueDate: _date(row['issueDate']),
        title: row['title'] as String,
        language: row['language'] == 'en'
            ? DocumentLanguage.english
            : DocumentLanguage.arabic,
        templateType: DocumentTemplateType.values.firstWhere(
          (value) => value.value == row['templateType'],
        ),
        status: DocumentStatus.values.firstWhere(
          (value) => value.value == row['status'],
        ),
        sourceEntityType: row['sourceEntityType'] as String?,
        sourceEntityId: row['sourceEntityId'] as String?,
        factoryId: row['factoryId'] as String?,
        createdBy: row['createdBy'] as String?,
        createdAt: _date(row['createdAt']),
        metadata: Map<String, Object?>.from(
          jsonDecode(row['metadata'] as String) as Map,
        ),
      );

  static DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
}
