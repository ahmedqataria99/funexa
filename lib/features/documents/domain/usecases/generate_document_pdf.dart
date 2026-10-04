import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';

class GenerateDocumentPdf {
  const GenerateDocumentPdf(this.repository);
  final DocumentsRepository repository;
  Future<List<int>> call(String documentId) =>
      repository.generatePdf(documentId);
}
