import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import '../utils/logout_helper.dart';

class PreviousScansTable extends StatefulWidget {
  final String itemName;
  final String title;
  final bool showClearButton;
  final VoidCallback? onDataCleared;

  const PreviousScansTable({
    Key? key,
    required this.itemName,
    this.title = 'Previous Scans',
    this.showClearButton = false,
    this.onDataCleared,
  }) : super(key: key);

  @override
  State<PreviousScansTable> createState() => _PreviousScansTableState();
}

class _PreviousScansTableState extends State<PreviousScansTable> {
  List<Map<String, dynamic>> _historicalData = [];
  int _currentPage = 1;
  static const int _pageSize = 10;
  int _totalItems = 0;
  bool _isLoadingHistory = false;
  String _searchQuery = '';
  String _sortColumn = 'created_at';
  bool _sortAscending = false;
  bool _isDevOperator = false;

  @override
  void initState() {
    super.initState();
    _loadHistoricalData();
    _checkIfDevOperator();
  }

  Future<void> _checkIfDevOperator() async {
    final currentUser = await DatabaseHelper().getCurrentUser();
    if (currentUser != null) {
      setState(() {
        _isDevOperator = currentUser['username'] == 'dev_operator';
      });
    }
  }

  Future<void> _loadHistoricalData() async {
    if (_isLoadingHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      print('\n=== DEBUG: PreviousScansTable._loadHistoricalData ===');
      print('Loading data for itemName: ${widget.itemName}');
      print('Current page: $_currentPage, Page size: $_pageSize');

      final data = await DatabaseHelper().getHistoricalScans(
        widget.itemName,
        page: _currentPage,
        pageSize: _pageSize,
      );

      print('Received historical data:');
      for (var row in data) {
        print(
            'Row: groupNumber=${row['groupNumber']}, display_group_number=${row['display_group_number']}');
      }

      final total =
          await DatabaseHelper().getHistoricalScansCount(widget.itemName);
      print('Total items count: $total');

      setState(() {
        _historicalData = data;
        _totalItems = total;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('Error loading historical data: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _loadNextPage() {
    if (_currentPage * _pageSize < _totalItems) {
      setState(() {
        _currentPage++;
      });
      _loadHistoricalData();
    }
  }

  void _loadPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _loadHistoricalData();
    }
  }

  void _sort<T>(
      String column, Comparable<T> Function(Map<String, dynamic>) getField) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }

      final mutableData = List<Map<String, dynamic>>.from(_historicalData);
      mutableData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return _sortAscending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
      _historicalData = mutableData;
    });
  }

  List<Map<String, dynamic>> _getFilteredData() {
    print('\n=== DEBUG: PreviousScansTable._getFilteredData ===');
    final data = _searchQuery.isEmpty
        ? _historicalData
        : List<Map<String, dynamic>>.from(_historicalData).where((item) {
            final searchLower = _searchQuery.toLowerCase();
            final itemName = (item['itemName'] ?? '').toLowerCase();
            final poNo = (item['poNo'] ?? '').toLowerCase();
            final content = (item['content'] ?? '').toLowerCase();
            final result = (item['result'] ?? '').toLowerCase();
            final date =
                DateTime.parse(item['created_at']).toString().toLowerCase();

            return itemName.contains(searchLower) ||
                poNo.contains(searchLower) ||
                content.contains(searchLower) ||
                result.contains(searchLower) ||
                date.contains(searchLower);
          }).toList();

    print('Filtered data:');
    for (var row in data) {
      print(
          'Row: groupNumber=${row['groupNumber']}, display_group_number=${row['display_group_number']}');
    }
    return data;
  }

  Future<void> _clearScans() async {
    try {
      await DatabaseHelper().clearIndividualScans(widget.itemName);
      setState(() {
        _historicalData.clear();
        _totalItems = 0;
        _currentPage = 1;
      });

      widget.onDataCleared?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All scans cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing scans: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    await _loadHistoricalData();
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: kBorderRadiusSmallAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search in previous scans...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: kBorderRadiusSmallAll,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          if (_isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_historicalData.isEmpty)
            const Text('No historical data available')
          else
            Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 48,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dataTableTheme: DataTableThemeData(
                            headingRowColor:
                                MaterialStateProperty.all(Colors.grey.shade100),
                            columnSpacing: 24,
                            horizontalMargin: 12,
                          ),
                        ),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('No.')),
                            DataColumn(label: Text('Content')),
                            DataColumn(label: Text('Result')),
                            DataColumn(label: Text('Date')),
                          ],
                          rows: _getFilteredData().map((scan) {
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                    scan['display_group_number']?.toString() ??
                                        '')),
                                DataCell(Text(scan['content'] ?? '')),
                                DataCell(
                                  Text(
                                    scan['result'] ?? '',
                                    style: TextStyle(
                                      color: scan['result'] == 'Good'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(Text(formatDate(scan['created_at']))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      bottomLeft: kBorderRadiusSmallAll.bottomLeft,
                      bottomRight: kBorderRadiusSmallAll.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${(_currentPage - 1) * _pageSize + 1} to ${_currentPage * _pageSize > _totalItems ? _totalItems : _currentPage * _pageSize} of $_totalItems entries',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed:
                                _currentPage > 1 ? _loadPreviousPage : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
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
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: kBorderRadiusSmallAll,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Page $_currentPage of ${(_totalItems / _pageSize).ceil()}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _currentPage * _pageSize < _totalItems
                                ? _loadNextPage
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
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
                if (widget.showClearButton && _isDevOperator) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _clearScans,
                        icon:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text(
                          'Clear All Scans (Dev Only)',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () =>
                            LogoutHelper.showLogoutConfirmation(context),
                        icon:
                            const Icon(Icons.logout, color: Colors.deepPurple),
                        label: const Text(
                          'Logout (Dev Only)',
                          style: TextStyle(color: Colors.deepPurple),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
