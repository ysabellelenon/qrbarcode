import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  void _showRemarksDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remarks'),
          content: TextField(
            controller: _remarksController,
            decoration: const InputDecoration(
              hintText: 'Enter remarks',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
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
            ElevatedButton(
              focusNode: FocusNode(),
              onPressed: () {
                Navigator.pop(context);
                _saveAndNavigate();
              },
              child: const Text('Done'),
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

  void _printSummary() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text('Review Summary', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Item Name: ${widget.itemName}'),
              pw.Text('Lot Number: ${widget.lotNumber}'),
              pw.Text('Content: ${widget.content}'),
              pw.Text('P.O Number: ${widget.poNo}'),
              pw.Text('Quantity: ${widget.quantity}'),
              pw.Text('Remarks: ${_remarksController.text}'),
              pw.SizedBox(height: 20),
              pw.Text('Results Table:', style: pw.TextStyle(fontSize: 18)),
              for (var entry in widget.tableData.asMap().entries)
                pw.Row(
                  children: [
                    pw.Text((entry.key + 1).toString()),
                    pw.Text(entry.value['content'] ?? ''),
                    pw.Text(entry.value['result'] ?? ''),
                  ],
                ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Summary'),
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
            const Text(
              'Results Table',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildResultsTable(),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
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
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _showRemarksDialog,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Add Remarks'),
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
            child: Text(
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

  Widget _buildResultsTable() {
    return Table(
      border: TableBorder.all(),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        const TableRow(
          children: [
            TableCell(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TableCell(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Content',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TableCell(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Result',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        ...widget.tableData.asMap().entries.map((entry) {
          return TableRow(
            children: [
              TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text((entry.key + 1).toString()),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(entry.value['content'] ?? ''),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(entry.value['result'] ?? ''),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }
}
