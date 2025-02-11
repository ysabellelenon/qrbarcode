import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' show mounted;
import '../database_helper.dart';

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

    // Get box quantities
    final boxQuantities = await DatabaseHelper().getBoxQuantities(itemName);

    // Reduce rows per page to avoid TooManyPagesException
    final int rowsPerPage = 25;
    final chunks = <List<Map<String, dynamic>>>[];

    // Process the table data to add display_group_number
    final processedData = <Map<String, dynamic>>[];
    Map<String, int> sessionGroupCounts = {};
    Map<String, int> sessionPositions = {};

    print('\n=== Input Table Data ===');
    print('Raw table data length: ${tableData.length}');
    tableData.forEach((row) {
      print('Input row: $row');
    });

    // Create a deep copy of the table data
    final List<Map<String, dynamic>> mutableTableData = tableData.map((row) {
      return Map<String, dynamic>.from(row);
    }).toList();

    // First pass: Group rows by sessionId and groupNumber to determine positions and results
    Map<String, List<Map<String, dynamic>>> groupedRows = {};
    for (var row in mutableTableData) {
      final key = '${row['sessionId']}_${row['groupNumber']}';
      groupedRows[key] = groupedRows[key] ?? [];
      groupedRows[key]!.add(row);
    }

    // Sort each group by created_at and update results
    groupedRows.forEach((key, rows) {
      // Sort by timestamp
      rows.sort((a, b) => DateTime.parse(a['created_at'])
          .compareTo(DateTime.parse(b['created_at'])));

      // Check if any scan in the group is No Good
      bool hasNoGood = rows.any((row) => row['result'] == 'No Good');

      // If any scan is No Good, mark all scans in the group as No Good
      if (hasNoGood) {
        for (var row in rows) {
          row['result'] = 'No Good';
        }
      }
    });

    print('\n=== Processing Table Data ===');
    // Second pass: Process rows with position information and synchronized results
    for (var row in mutableTableData) {
      print('\nProcessing row with content: ${row['content']}');
      print('Raw row data: $row');

      // Create a new map with string values for display_group_number
      Map<String, dynamic> processedRow = Map<String, dynamic>.from(row);
      print('Initial processed row: $processedRow');

      // Find position in group
      final key = '${row['sessionId']}_${row['groupNumber']}';
      final groupRows = groupedRows[key]!;
      final position = groupRows.indexWhere((r) => r['id'] == row['id']) + 1;
      print('Position in group: $position');

      // Set display_group_number based on position
      if (position == 1) {
        processedRow['display_group_number'] = row['groupNumber'].toString();
        print(
            'First in group, setting display_group_number to: ${processedRow['display_group_number']}');
      } else {
        processedRow['display_group_number'] = '';
        print('Not first in group, using empty string');
      }

      // Use the synchronized result from the grouped data
      processedRow['result'] =
          groupRows.firstWhere((r) => r['id'] == row['id'])['result'];

      print('Final processed row: $processedRow');
      processedData.add(processedRow);
    }

    print('\n=== Final Processed Data ===');
    print('Processed data length: ${processedData.length}');
    processedData.forEach((row) {
      print(
          'Final row: display_group_number=[${row['display_group_number']}], content=${row['content']}, result=${row['result']}');
    });

    // Split into chunks for pagination
    print('\n=== Chunking Data ===');
    for (var i = 0; i < processedData.length; i += rowsPerPage) {
      final chunk = processedData.sublist(
        i,
        i + rowsPerPage > processedData.length
            ? processedData.length
            : i + rowsPerPage,
      );
      print('Created chunk with ${chunk.length} rows');
      chunks.add(chunk);
    }
    print('Created ${chunks.length} chunks');

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

    // Get total counts
    final totalCounts =
        await DatabaseHelper().getTotalGoodNoGoodCounts(itemName);
    final totalScans = await DatabaseHelper().getTotalScansForItem(itemName);

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
                        pw.Text('Total QTY: $quantity', style: baseTextStyle),
                        pw.SizedBox(height: 5),
                        pw.Text('Remarks: $remarks', style: baseTextStyle),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Summary Counts:', style: headerTextStyle),
                    pw.SizedBox(height: 5),
                    pw.Text('Total QTY: $quantity', style: baseTextStyle),
                    pw.Text('Total Inspection QTY: $totalScans',
                        style: baseTextStyle),
                    pw.Text('Total Good Count: ${totalCounts['goodCount']}',
                        style: baseTextStyle),
                    pw.Text(
                        'Total No Good Count: ${totalCounts['noGoodCount']}',
                        style: baseTextStyle),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Box Quantities:', style: headerTextStyle),
                    pw.SizedBox(height: 5),
                    ...boxQuantities.map((box) {
                      final DateTime createdAt =
                          DateTime.parse(box['createdAt']);
                      final String formattedDate =
                          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
                      return pw.Text(
                        'Box (${formattedDate}): Target QTY: ${box['qtyPerBox']}, Good: ${box['goodGroups']}, No Good: ${box['noGoodGroups']}',
                        style: baseTextStyle,
                      );
                    }).toList(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Results Table:', style: headerTextStyle),
              pw.SizedBox(height: 10),
            ],
          );
        },
        build: (pw.Context context) {
          print('\n=== Building PDF Table ===');
          return chunks.map((chunk) {
            print('\nProcessing chunk with ${chunk.length} rows');
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
                      print('\n=== Generating PDF Table Row ===');
                      print('Row index: $index');
                      print('Raw row data: ${entry.value}');
                      print(
                          'Display group number (raw): ${entry.value['display_group_number']}');

                      // Ensure we have a string value for display_group_number
                      String displayNumber = '';
                      if (entry.value['display_group_number'] != null) {
                        displayNumber =
                            entry.value['display_group_number'].toString();
                        print('Using display number: "$displayNumber"');
                      } else {
                        print('No display number found, using empty string');
                      }

                      print(
                          'Creating table row with display number: "$displayNumber"');

                      return pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              displayNumber,
                              style: baseTextStyle,
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                                entry.value['content']?.toString() ?? '',
                                style: baseTextStyle),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              entry.value['result']?.toString() ?? '',
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
