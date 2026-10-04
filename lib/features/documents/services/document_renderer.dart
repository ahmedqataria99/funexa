import 'package:furnexa/features/documents/domain/entities/document_entity.dart';

abstract class DocumentRenderer {
  Future<List<int>> render(DocumentEntity document);
}
