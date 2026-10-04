import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_number.dart';
import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';

class GetNextDocumentNumber {
  const GetNextDocumentNumber(this.repository);
  final DocumentsRepository repository;
  Future<DocumentNumber> call(DocumentType type, {DateTime? date}) =>
      repository.getNextNumber(type, date: date);
}
