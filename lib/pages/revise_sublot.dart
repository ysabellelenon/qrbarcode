import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import '../utils/logout_helper.dart';
import 'item_masterlist.dart';

class ReviseSublot extends StatefulWidget {
  final int itemId;
  final String itemName;
  final String revision;
  final List<Map<String, String>> countingCodes;
  final List<Map<String, dynamic>> allCodes;

  const ReviseSublot({
    Key? key,
    required this.itemId,
    required this.itemName,
    required this.revision,
    required this.countingCodes,
    required this.allCodes,
  }) : super(key: key);

  @override
  State<ReviseSublot> createState() => _ReviseSublotState();
}

class _ReviseSublotState extends State<ReviseSublot> {
  final Map<String, bool> enableRules = {};
  final Map<String, String> selectedSerialCounts = {};
  final List<String> _serialCounts = List.generate(20, (i) => (i + 1).toString());

  @override
  void initState() {
    super.initState();
    // Initialize maps for each counting code
    for (var code in widget.countingCodes) {
      // Find the corresponding code in allCodes to get existing values
      final existingCode = widget.allCodes.firstWhere(
        (c) => c['content'] == code['content'],
        orElse: () => {'hasSubLot': false, 'serialCount': '1'},
      );
      
      enableRules[code['content']!] = existingCode['hasSubLot'] ?? false;
      selectedSerialCounts[code['content']!] = existingCode['serialCount']?.toString() ?? '1';
    }
  }

  Widget _buildConfigContainer(String labelContent) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: kBorderRadiusSmallAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          children: [
            Checkbox(
              value: enableRules[labelContent],
              onChanged: (value) {
                setState(() {
                  enableRules[labelContent] = value ?? false;
                });
              },
            ),
            SelectableText('Enable Sub-Lot number rules for "$labelContent"'),
            const Spacer(),
            const SelectableText('Number of serial no. for'),
            const SizedBox(width: 8),
            SelectableText('"$labelContent"'),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                value: selectedSerialCounts[labelContent],
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: kBorderRadiusSmallAll,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: kBorderRadiusSmallAll,
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: kBorderRadiusSmallAll,
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _serialCounts.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedSerialCounts[labelContent] = newValue ?? '1';
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateItem() async {
    try {
      final now = DateTime.now().toIso8601String();
      // Update the allCodes with new sublot configurations
      final updatedCodes = widget.allCodes.map((code) {
        if (code['category'] == 'Counting') {
          return {
            ...code,
            'hasSubLot': enableRules[code['content']] == true ? 1 : 0,
            'serialCount': selectedSerialCounts[code['content']] ?? '1',
            'isActive': 1,
            'lastUpdated': now,
          };
        }
        return {
          ...code,
          'isActive': 1,
          'lastUpdated': now,
        };
      }).toList();

      // Prepare the complete updated item data
      final updatedItem = {
        'itemCode': widget.itemName,
        'revision': widget.revision,
        'codeCount': widget.allCodes.length.toString(),
        'codes': updatedCodes,
        'isActive': 1,
        'lastUpdated': now,
      };

      // Update the item in the database
      await DatabaseHelper().updateItem(widget.itemId, updatedItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ItemMasterlist(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating item: $e'),
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Revise Sub-Lot Configuration',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Generate a container for each counting code
                  ...widget.countingCodes.map((code) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildConfigContainer(code['content']!),
                      )),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: kBorderRadiusSmallAll,
                        ),
                      ),
                      onPressed: _updateItem,
                      child: const Text('Save Changes'),
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