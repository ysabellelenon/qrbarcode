import 'package:flutter/material.dart';
import '../database_helper.dart';

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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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
        ),
      ),
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
  }) : super(key: key);

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
            _buildInfoSection('Date', date.toString()),
            _buildInfoSection('Content', content),
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
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: const Text('This will print the summary.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
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
                          'tableData': tableData.map((item) => Map<String, dynamic>.from(item)).toList(),
                        });

                        // Navigate to login page
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Error'),
                              content: Text('Failed to save unfinished item: $e'),
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
              label + ':',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
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