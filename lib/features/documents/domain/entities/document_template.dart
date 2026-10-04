import 'document_definition.dart';

class DocumentTemplate {
  const DocumentTemplate({
    required this.type,
    required this.pageFormat,
    required this.isNarrow,
  });
  final DocumentTemplateType type;
  final String pageFormat;
  final bool isNarrow;

  static const standard = DocumentTemplate(
    type: DocumentTemplateType.standard,
    pageFormat: 'A4',
    isNarrow: false,
  );
  static const compact = DocumentTemplate(
    type: DocumentTemplateType.compact,
    pageFormat: 'A4',
    isNarrow: false,
  );
  static const thermal = DocumentTemplate(
    type: DocumentTemplateType.thermal,
    pageFormat: 'THERMAL',
    isNarrow: true,
  );
}
