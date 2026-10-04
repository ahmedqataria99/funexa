import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'package:furnexa/features/documents/domain/repositories/documents_repository.dart';

class DocumentPreviewPage extends StatelessWidget {
  const DocumentPreviewPage({
    super.key,
    required this.document,
    required this.repository,
  });
  final DocumentEntity document;
  final DocumentsRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(document.title)),
    body: PdfPreview(
      canChangeOrientation: false,
      canChangePageFormat: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: '${document.documentNumber}.pdf',
      build: (format) async =>
          Uint8List.fromList(await repository.generatePdf(document.documentId)),
    ),
  );
}
