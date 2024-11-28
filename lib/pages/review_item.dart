import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import '../utils/logout_helper.dart';

class ReviewItem extends StatelessWidget {
  final int? itemId;
  final String itemName;
  final String revision;
  final int codeCount;
  final List<Map<String, dynamic>> codes;
  final bool isUpdate;

  const ReviewItem({
    super.key,
    this.itemId,
    required this.itemName,
    required this.revision,
    required this.codeCount,
    required this.codes,
    this.isUpdate = false,
  });

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _registerItem(BuildContext context) async {
    try {
      // Create item map for database
      final item = {
        'itemCode': itemName,
        'revision': revision,
        'codeCount': codeCount.toString(),
        'codes': codes.map((code) => {
              'category': code['category'],
              'content': code['content'],
              'hasSubLot': code['hasSubLot'] ? 1 : 0,
              'serialCount': code['serialCount'] ?? '0',
            }).toList(),
      };

      if (isUpdate && itemId != null) {
        // Update existing item
        await DatabaseHelper().updateItem(itemId!, item);
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Insert new item
        await DatabaseHelper().insertItem(item);
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Navigate to item masterlist
      Navigator.pushReplacementNamed(context, '/item-masterlist');
    } catch (e) {
      // Show error message if something goes wrong
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          // App Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'QR Barcode System',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => LogoutHelper.showLogoutConfirmation(context),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/sublot-config'),
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),

                  // All content in one white container
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item Details Section
                        const Text(
                          'Item Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildInfoRow('Item Name', itemName),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow('Rev No.', revision),
                            ),
                            Expanded(
                              child: _buildInfoRow('No. of Code', codeCount.toString()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Code Details Section
                        ...codes.asMap().entries.map((entry) {
                          final index = entry.key;
                          final code = entry.value;
                          return _buildCodeSection(code, index);
                        }),

                        // Register Button
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _registerItem(context),
                            child: const Text('Register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSection(Map<String, dynamic> code, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code ${index + 1}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildInfoRow('Category', code['category']),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: _buildInfoRow('Label Content', code['content']),
            ),
          ],
        ),
        // Only show Sub-lot Configuration for Counting category
        if (code['category'] == 'Counting') ...[
          const SizedBox(height: 24),
          Text(
            'Sub-lot Configuration',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Sub-lot Rules Enabled',
            code['hasSubLot'] ? 'Yes' : 'No',
          ),
          if (code['hasSubLot'])
            _buildInfoRow('Number of Serial No.', code['serialCount']),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
} 