import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';

class GetDocumentHistory {
  const GetDocumentHistory(this.repository);
  final DocumentsRepository repository;
  Future<List<DocumentEntity>> call({DocumentType? type}) =>
      repository.history(type: type);
}
