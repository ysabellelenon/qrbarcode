import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show mounted;

Future<void> generateAndSavePdf({
  required String itemName,
  required String lotNumber,
  required String content,
  required String poNo,
  required String quantity,
  required List<Map<String, dynamic>> tableData,
  required String remarks,
  required bool isEmergencyStop,
  required Function(String) onSuccess,
  required Function(String) onError,
}) async {
  try {
    final pdf = pw.Document();

    // Reduce rows per page to avoid TooManyPagesException
    final int rowsPerPage = 25;
    final chunks = <List<Map<String, dynamic>>>[];

    for (var i = 0; i < tableData.length; i += rowsPerPage) {
      chunks.add(
        tableData.sublist(
          i,
          i + rowsPerPage > tableData.length
              ? tableData.length
              : i + rowsPerPage,
        ),
      );
    }

    // Create styles
    final baseTextStyle = pw.TextStyle(
      fontSize: 10,
      font: pw.Font.courier(),
    );

    final headerTextStyle = pw.TextStyle(
      fontSize: 12,
      font: pw.Font.courier(),
      fontWeight: pw.FontWeight.bold,
    );

    final titleTextStyle = pw.TextStyle(
      fontSize: 16,
      font: pw.Font.courier(),
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                  isEmergencyStop ? 'Emergency Stop Summary' : 'Review Summary',
                  style: titleTextStyle),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Item Name: $itemName', style: baseTextStyle),
                        pw.SizedBox(height: 5),
                        pw.Text('Lot Number: $lotNumber', style: baseTextStyle),
                        pw.SizedBox(height: 5),
                        pw.Text('Content: $content', style: baseTextStyle),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('P.O Number: $poNo', style: baseTextStyle),
                        pw.SizedBox(height: 5),
                        pw.Text('Quantity: $quantity', style: baseTextStyle),
                        pw.SizedBox(height: 5),
                        pw.Text('Remarks: $remarks', style: baseTextStyle),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Results Table:', style: headerTextStyle),
              pw.SizedBox(height: 10),
            ],
          );
        },
        build: (pw.Context context) {
          return chunks.map((chunk) {
            return pw.Column(
              children: [
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('No.', style: headerTextStyle),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Content', style: headerTextStyle),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Result', style: headerTextStyle),
                        ),
                      ],
                    ),
                    ...chunk.asMap().entries.map((entry) {
                      final index =
                          chunks.indexOf(chunk) * rowsPerPage + entry.key;
                      return pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text((index + 1).toString(),
                                style: baseTextStyle),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(entry.value['content'] ?? '',
                                style: baseTextStyle),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              entry.value['result'] ?? '',
                              style: baseTextStyle.copyWith(
                                color: entry.value['result'] == 'Good'
                                    ? PdfColors.green
                                    : PdfColors.red,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                if (chunks.indexOf(chunk) < chunks.length - 1)
                  pw.SizedBox(height: 20),
              ],
            );
          }).toList();
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 12),
            ),
          );
        },
      ),
    );

    // Get default file name
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final String defaultFileName =
        '${isEmergencyStop ? 'emergency_stop' : 'review_summary'}_${itemName}_$timestamp.pdf';

    // Show save file dialog
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF File',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputFile != null) {
      if (!outputFile.toLowerCase().endsWith('.pdf')) {
        outputFile = '$outputFile.pdf';
      }

      final file = File(outputFile);
      await file.writeAsBytes(await pdf.save());
      onSuccess(outputFile);
    }
  } catch (e) {
    print('Error generating PDF: $e');
    onError(e.toString());
  }
}
