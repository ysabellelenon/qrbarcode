import 'package:flutter/material.dart';
import '../constants.dart';

class ReviewItem extends StatelessWidget {
  final String itemName;
  final String revision;
  final int codeCount;
  final List<Map<String, dynamic>> codes;

  const ReviewItem({
    super.key,
    required this.itemName,
    required this.revision,
    required this.codeCount,
    required this.codes,
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
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
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
                    onPressed: () => Navigator.pop(context),
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
                              const SizedBox(height: 16),

                              // Sub-lot Configuration Section
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
                              const SizedBox(height: 16),
                            ],
                          );
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
                            onPressed: () {
                              // Handle registration
                            },
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
} 