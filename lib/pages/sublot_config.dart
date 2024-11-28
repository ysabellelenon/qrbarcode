import 'package:flutter/material.dart';
import '../constants.dart';
import 'review_item.dart';
import '../utils/logout_helper.dart';

class SublotConfig extends StatefulWidget {
  final String itemName;
  final List<Map<String, String>> countingCodes;
  final bool isUpdate;
  final int? itemId;
  final List<Map<String, dynamic>>? allCodes;
  final String? revision;

  const SublotConfig({
    super.key,
    required this.itemName,
    required this.countingCodes,
    this.isUpdate = false,
    this.itemId,
    this.allCodes,
    this.revision,
  });

  @override
  State<SublotConfig> createState() => _SublotConfigState();
}

class _SublotConfigState extends State<SublotConfig> {
  final Map<String, bool> enableRules = {};
  final Map<String, String> selectedSerialCounts = {};
  final List<String> _serialCounts = List.generate(20, (i) => (i + 1).toString());

  @override
  void initState() {
    super.initState();
    // Initialize maps for each counting code
    for (var code in widget.countingCodes) {
      enableRules[code['content']!] = false;
      selectedSerialCounts[code['content']!] = '1';
    }
  }

  Widget _buildConfigContainer(String labelContent) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
            Text('Enable Sub-Lot number rules for "$labelContent"'),
            const Spacer(),
            if (enableRules[labelContent] ?? false) ...[
              const Text('Number of serial no. for'),
              const SizedBox(width: 8),
              Text('"$labelContent"'),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  value: selectedSerialCounts[labelContent],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _serialCounts.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedSerialCounts[labelContent] = newValue ?? '';
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
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
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/register-item'),
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'Sub-Lot Configuration',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Generate a container for each counting code
                  ...widget.countingCodes.map((code) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildConfigContainer(code['content']!),
                    )
                  ),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () {
                        // Create a list of codes with their configurations
                        final configuredCodes = widget.countingCodes.map((code) {
                          return {
                            'code': code['code'],
                            'content': code['content'],
                            'category': 'Counting',
                            'hasSubLot': enableRules[code['content']] ?? false,
                            'serialCount': enableRules[code['content']] ?? false 
                                ? selectedSerialCounts[code['content']] 
                                : '0',
                          };
                        }).toList();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReviewItem(
                              itemId: widget.itemId,
                              itemName: widget.itemName,
                              revision: widget.revision ?? '1',
                              codeCount: widget.allCodes?.length ?? widget.countingCodes.length,
                              codes: configuredCodes + (widget.allCodes?.where((code) => code['category'] != 'Counting').map((code) {
                                return {
                                  'code': code['code'],
                                  'content': code['content'],
                                  'category': code['category'],
                                  'hasSubLot': false,
                                  'serialCount': '0',
                                };
                              }).toList() ?? []),
                              isUpdate: widget.isUpdate,
                            ),
                          ),
                        );
                      },
                      child: const Text('Next'),
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