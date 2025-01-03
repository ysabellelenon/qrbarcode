import 'package:flutter/material.dart';
import 'package:qrbarcode/constants.dart';
import '../database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class FinishedItem extends StatefulWidget {
  final String itemName;
  final String lotNumber;
  final String content;
  final String poNo;
  final String quantity;
  final List<Map<String, dynamic>> tableData;

  const FinishedItem({
    Key? key,
    required this.itemName,
    required this.lotNumber,
    required this.content,
    required this.poNo,
    required this.quantity,
    required this.tableData,
  }) : super(key: key);

  @override
  _FinishedItemState createState() => _FinishedItemState();
}

class _FinishedItemState extends State<FinishedItem> {
  final TextEditingController _remarksController = TextEditingController();
  List<Map<String, dynamic>> _scannedData = [];
  bool _isLoading = true;

  // Add pagination variables
  int _currentPage = 1;
  static const int _pageSize = 10;
  String _searchQuery = '';
  String _sortColumn = 'created_at';
  bool _sortAscending = false;
  List<Map<String, dynamic>> _displayData = [];
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadScannedData();
  }

  Future<void> _loadScannedData() async {
    try {
      final scans =
          await DatabaseHelper().getAllHistoricalScans(widget.itemName);
      setState(() {
        _scannedData = scans;
        _displayData = _scannedData;
        _totalItems = _scannedData.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading scanned data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateDisplayData() {
    // Filter data based on search query
    var filteredData = _scannedData.where((item) {
      if (_searchQuery.isEmpty) return true;
      final searchLower = _searchQuery.toLowerCase();
      final content = (item['content'] ?? '').toLowerCase();
      final result = (item['result'] ?? '').toLowerCase();
      return content.contains(searchLower) || result.contains(searchLower);
    }).toList();

    // Sort data
    filteredData.sort((a, b) {
      if (_sortColumn == 'content') {
        return _sortAscending
            ? (a['content'] ?? '').compareTo(b['content'] ?? '')
            : (b['content'] ?? '').compareTo(a['content'] ?? '');
      } else if (_sortColumn == 'result') {
        return _sortAscending
            ? (a['result'] ?? '').compareTo(b['result'] ?? '')
            : (b['result'] ?? '').compareTo(a['result'] ?? '');
      }
      return 0;
    });

    setState(() {
      _displayData = filteredData;
      _totalItems = filteredData.length;
    });
  }

  Widget _buildResultsTable() {
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize;
    final paginatedData = _displayData.sublist(
      startIndex,
      endIndex > _displayData.length ? _displayData.length : endIndex,
    );

    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search in results...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _currentPage = 1;
                _updateDisplayData();
              });
            },
          ),
        ),

        // Results table
        Table(
          border: TableBorder.all(),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              children: [
                TableCell(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_sortColumn == 'no') {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortColumn = 'no';
                          _sortAscending = true;
                        }
                        _updateDisplayData();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const SelectableText(
                            'No.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_sortColumn == 'no')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                TableCell(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_sortColumn == 'content') {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortColumn = 'content';
                          _sortAscending = true;
                        }
                        _updateDisplayData();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const SelectableText(
                            'Content',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_sortColumn == 'content')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                TableCell(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_sortColumn == 'result') {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortColumn = 'result';
                          _sortAscending = true;
                        }
                        _updateDisplayData();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const SelectableText(
                            'Result',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_sortColumn == 'result')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ...paginatedData.asMap().entries.map((entry) {
              final index = startIndex + entry.key;
              final item = entry.value;
              return TableRow(
                children: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SelectableText((index + 1).toString()),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SelectableText(item['content'] ?? ''),
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SelectableText(
                        item['result'] ?? '',
                        style: TextStyle(
                          color: item['result'] == 'Good'
                              ? Colors.green
                              : item['result'] == 'No Good'
                                  ? Colors.red
                                  : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),

        // Pagination controls
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${startIndex + 1} to ${startIndex + paginatedData.length} of $_totalItems entries',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, size: 16),
                        SizedBox(width: 4),
                        Text('Previous'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Page $_currentPage of ${(_totalItems / _pageSize).ceil()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: endIndex < _totalItems
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                    child: const Row(
                      children: [
                        Text('Next'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _printSummary() async {
    try {
      final pdf = pw.Document();

      // Reduce rows per page to avoid TooManyPagesException
      final int rowsPerPage = 25;
      final chunks = <List<Map<String, dynamic>>>[];

      for (var i = 0; i < _scannedData.length; i += rowsPerPage) {
        chunks.add(
          _scannedData.sublist(
            i,
            i + rowsPerPage > _scannedData.length
                ? _scannedData.length
                : i + rowsPerPage,
          ),
        );
      }

      // Create a base style for all text
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
                pw.Text('Review Summary', style: titleTextStyle),
                pw.SizedBox(height: 20),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Item Name: ${widget.itemName}',
                              style: baseTextStyle),
                          pw.SizedBox(height: 5),
                          pw.Text('Lot Number: ${widget.lotNumber}',
                              style: baseTextStyle),
                          pw.SizedBox(height: 5),
                          pw.Text('Content: ${widget.content}',
                              style: baseTextStyle),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('P.O Number: ${widget.poNo}',
                              style: baseTextStyle),
                          pw.SizedBox(height: 5),
                          pw.Text('Quantity: ${widget.quantity}',
                              style: baseTextStyle),
                          pw.SizedBox(height: 5),
                          pw.Text('Remarks: ${_remarksController.text}',
                              style: baseTextStyle),
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
                style: pw.TextStyle(
                  fontSize: 12,
                ),
              ),
            );
          },
        ),
      );

      // Get default file name
      final String timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-');
      final String defaultFileName =
          'review_summary_${widget.itemName}_$timestamp.pdf';

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

        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Success'),
                shape: RoundedRectangleBorder(
                  borderRadius: kBorderRadiusSmallAll,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PDF saved successfully to:'),
                    const SizedBox(height: 8),
                    SelectableText(outputFile!),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        if (Platform.isMacOS) {
                          await Process.run('open', [outputFile!]);
                        } else if (Platform.isWindows) {
                          await Process.run(
                              'cmd', ['/c', 'start', '', outputFile!]);
                        }
                      } catch (e) {
                        print('Error opening file: $e');
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Error'),
                                content: Text('Failed to open file: $e'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      }
                    },
                    child: const Text('Open File'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to generate PDF: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SelectableText('Review Summary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection('Item Name', widget.itemName),
            _buildInfoSection('Lot Number', widget.lotNumber),
            _buildInfoSection('Date', _formatDate(DateTime.now())),
            _buildInfoSection(
                'Content', '${widget.content}_${widget.lotNumber}'),
            _buildInfoSection('P.O Number', widget.poNo),
            _buildInfoSection('Quantity', widget.quantity),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SelectableText(
                    'Results Table',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildResultsTable(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(
                      onPressed: _printSummary,
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      onPressed: _showRemarksDialog,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('Add Remarks'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SelectableText(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  void _showRemarksDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const SelectableText('Remarks'),
          shape: RoundedRectangleBorder(
            borderRadius: kBorderRadiusSmallAll,
          ),
          content: TextField(
            controller: _remarksController,
            decoration: const InputDecoration(
              hintText: 'Enter remarks',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onSubmitted: (_) {
              Navigator.pop(context);
              _saveAndNavigate();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FocusScope(
              autofocus: true,
              child: ElevatedButton(
                autofocus: true,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _saveAndNavigate();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveAndNavigate() async {
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/operator-login',
        (route) => false,
      );
    }
  }
}
