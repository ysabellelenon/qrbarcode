import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EmergencyStop extends StatefulWidget {
  final String itemName;
  final String lotNumber;
  final String content;
  final String poNo;
  final String quantity;
  final List<Map<String, dynamic>> tableData;
  final String username;

  const EmergencyStop({
    Key? key,
    required this.itemName,
    required this.lotNumber,
    required this.content,
    required this.poNo,
    required this.quantity,
    required this.tableData,
    required this.username,
  }) : super(key: key);

  @override
  _EmergencyStopState createState() => _EmergencyStopState();
}

class _EmergencyStopState extends State<EmergencyStop> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  String _errorMessage = '';

  void _validatePassword() async {
    final user = await DatabaseHelper().getUserByUsernameAndPassword(
      widget.username,
      _passwordController.text,
    );

    if (user != null) {
      _showRemarksDialog();
    } else {
      setState(() {
        _errorMessage = 'Invalid password';
      });
    }
  }

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
              hintText: 'Enter reason for temporary stoppage',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
            onSubmitted: (_) {
              Navigator.pop(context);
              _showSummaryPage();
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
                _showSummaryPage();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showSummaryPage() {
    print('EmergencyStop - Showing summary with:');
    print('itemName: ${widget.itemName}');
    print('lotNumber: ${widget.lotNumber}');
    print('content: ${widget.content}');
    print('poNo: ${widget.poNo}');
    print('quantity: ${widget.quantity}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencySummary(
          itemName: widget.itemName,
          lotNumber: widget.lotNumber,
          date: DateTime.now(),
          content: widget.content,
          poNo: widget.poNo,
          quantity: widget.quantity,
          tableData: widget.tableData,
          remarks: _remarksController.text,
          onPrint: _printSummary,
        ),
      ),
    );
  }

  void _printSummary() async {
    // Create a PDF document
    final pdf = pw.Document();

    // Add a page to the PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text('Emergency Stop Summary',
                  style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Item Name: ${widget.itemName}'),
              pw.Text('Lot Number: ${widget.lotNumber}'),
              pw.Text('Content: ${widget.content}'),
              pw.Text('P.O Number: ${widget.poNo}'),
              pw.Text('Quantity: ${widget.quantity}'),
              pw.Text('Remarks: ${_remarksController.text}'),
              pw.SizedBox(height: 20),
              pw.Text('Results Table:', style: pw.TextStyle(fontSize: 18)),
              // Add your table data here
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

    // Print the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emergency Stop'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please enter password to confirm'),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) {
              _validatePassword();
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validatePassword,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class EmergencySummary extends StatelessWidget {
  final String itemName;
  final String lotNumber;
  final DateTime date;
  final String content;
  final String poNo;
  final String quantity;
  final List<Map<String, dynamic>> tableData;
  final String remarks;
  final VoidCallback onPrint;

  const EmergencySummary({
    Key? key,
    required this.itemName,
    required this.lotNumber,
    required this.date,
    required this.content,
    required this.poNo,
    required this.quantity,
    required this.tableData,
    required this.remarks,
    required this.onPrint,
  }) : super(key: key);

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  String get _combinedContent => '${content}_$lotNumber';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Stop Summary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection('Item Name', itemName),
            _buildInfoSection('Lot Number', lotNumber),
            _buildInfoSection('Date', _formatDate(date)),
            _buildInfoSection('Content', _combinedContent),
            _buildInfoSection('P.O Number', poNo),
            _buildInfoSection('Quantity', quantity),
            _buildInfoSection('Remarks', remarks),
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
                    onPressed: () {
                      onPrint();
                    },
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
                    onPressed: () async {
                      try {
                        // Save to unfinished items in database
                        await DatabaseHelper().insertUnfinishedItem({
                          'itemName': itemName,
                          'lotNumber': lotNumber,
                          'date': date.toIso8601String(),
                          'content': content,
                          'poNo': poNo,
                          'quantity': quantity,
                          'remarks': remarks,
                          'tableData': tableData
                              .map((item) => Map<String, dynamic>.from(item))
                              .toList(),
                        });

                        // Navigate to login page
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login', (route) => false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Error'),
                              content:
                                  Text('Failed to save unfinished item: $e'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            child: Text(value.isEmpty ? '-' : value),
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
        ...tableData.asMap().entries.map((entry) {
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
