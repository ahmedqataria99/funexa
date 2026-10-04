import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';

class PrintDocument {
  const PrintDocument(this.repository);
  final DocumentsRepository repository;
  Future<void> call(String documentId) => repository.printDocument(documentId);
}
