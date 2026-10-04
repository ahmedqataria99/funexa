import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';

class PreviewDocument {
  const PreviewDocument(this.repository);
  final DocumentsRepository repository;
  Future<DocumentEntity?> call(String documentId) =>
      repository.getById(documentId);
}
