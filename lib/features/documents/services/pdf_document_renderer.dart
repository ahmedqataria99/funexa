import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/documents/domain/entities/document_entity.dart';
import 'document_renderer.dart';

class PdfDocumentRenderer implements DocumentRenderer {
  @override
  Future<List<int>> render(DocumentEntity document) async {
    final pdf = pw.Document();
    final font = pw.Font.ttf(
      (await rootBundle.load(
        'assets/fonts/NotoSansArabic-Regular.ttf',
      )).buffer.asByteData(),
    );
    final bold = pw.Font.ttf(
      (await rootBundle.load(
        'assets/fonts/NotoSansArabic-Bold.ttf',
      )).buffer.asByteData(),
    );
    final rtl = document.language == DocumentLanguage.arabic;
    final format = document.templateType == DocumentTemplateType.thermal
        ? PdfPageFormat(
            80 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 8 * PdfPageFormat.mm,
          )
        : PdfPageFormat.a4;
    final metadata = document.metadata;
    final columns =
        (metadata['columns'] as List?)?.map((value) => '$value').toList() ??
        const <String>[];
    final rows =
        (metadata['rows'] as List?)
            ?.map(
              (row) =>
                  (row as Map).map((key, value) => MapEntry('$key', value)),
            )
            .toList() ??
        const <Map<String, Object?>>[];
    final header = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('FURNEXA ERP', style: pw.TextStyle(font: bold, fontSize: 16)),
        pw.SizedBox(height: 4),
        pw.Text(document.title, style: pw.TextStyle(font: bold, fontSize: 14)),
        pw.Text(
          document.documentNumber,
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.Text(
          DateFormat('yyyy-MM-dd').format(document.issueDate),
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.Divider(),
      ],
    );
    final table = columns.isEmpty
        ? pw.SizedBox()
        : pw.TableHelper.fromTextArray(
            headers: columns,
            data: rows
                .map(
                  (row) =>
                      columns.map((column) => '${row[column] ?? ''}').toList(),
                )
                .toList(),
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            cellStyle: pw.TextStyle(font: font, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: rtl
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
          );
    final notes = metadata['notes'];
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        margin: pw.EdgeInsets.all(
          document.templateType == DocumentTemplateType.compact ? 24 : 36,
        ),
        footer: (context) => pw.Directionality(
          textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          child: pw.Align(
            alignment: rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: pw.Text(
              '${document.documentNumber}  |  ${context.pageNumber}/${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: header,
          ),
          pw.Directionality(
            textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: table,
          ),
          if (notes != null)
            pw.Directionality(
              textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Text(
                  '$notes',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ),
            ),
          pw.SizedBox(height: 28),
          pw.Directionality(
            textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  rtl ? 'أعده' : 'Prepared by',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
                pw.Text(
                  rtl ? 'اعتمده' : 'Approved by',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }
}
