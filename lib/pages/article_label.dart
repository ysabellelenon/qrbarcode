import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import database helper
import 'scan_item.dart'; // Import the ScanItem page

class ArticleLabel extends StatefulWidget {
  final String? itemName;
  final String? poNo;
  final int? operatorScanId;
  final int? totalQty;
  final Map<String, dynamic>? resumeData;

  const ArticleLabel({
    Key? key,
    this.itemName,
    this.poNo,
    this.operatorScanId,
    this.totalQty,
    this.resumeData,
  }) : super(key: key);

  @override
  _ArticleLabelState createState() => _ArticleLabelState();
}

class _ArticleLabelState extends State<ArticleLabel> {
  final TextEditingController articleLabelController = TextEditingController();
  final TextEditingController lotNumberController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  bool isError = false; // Track if there's an error

  String get itemName => widget.resumeData?['itemName'] ?? widget.itemName ?? '';
  String get poNo => widget.resumeData?['poNo'] ?? widget.poNo ?? '';
  int get operatorScanId => widget.resumeData?['operatorScanId'] ?? widget.operatorScanId ?? 0;
  int get totalQty => widget.resumeData?['totalQty'] ?? widget.totalQty ?? 0;

  void _validateArticleLabel(String articleLabel) {
    if (articleLabel.length >= 22) {
      String firstPart = articleLabel.split(' ')[0];

      if (firstPart.length >= 12) {
        String extractedItemName = firstPart.substring(12);

        List<String> parts = articleLabel.split(' ');

        String extractedPoNo = '';
        if (parts.length > 3) {
          extractedPoNo = parts[3].substring(0, 10); // First 10 digits after the third space
        } else {
          setState(() {
            isError = true; // Set error flag
          });
          return; // Exit early
        }

        if (extractedItemName.trim() != itemName || extractedPoNo != poNo) {
          setState(() {
            isError = true; // Set error flag
          });
        } else {
          setState(() {
            isError = false; // Clear error flag
          });

          String lotNumber = parts.last; // Last part after space
          String qtyPerBox = '';
          if (parts.length > 2) {
            String qtyPart = parts.sublist(2).join(' '); // Join the remaining parts after the second space
            RegExp qtyRegExp = RegExp(r'(\d+)'); // Regex to find all digits
            Match? match = qtyRegExp.firstMatch(qtyPart);
            qtyPerBox = match != null ? match.group(1) ?? '' : ''; // Get the first match of digits
          }

          lotNumberController.text = lotNumber;
          qtyController.text = qtyPerBox;
        }
      } else {
        setState(() {
          isError = true; // Set error flag
        });
        return; // Exit early
      }
    } else {
      setState(() {
        isError = true; // Set error flag
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Back Button
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Back'),
            ),
          ),
          const SizedBox(height: 20),

          // Heading
          const Center(
            child: Text(
              'Article Label',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: Colors.white, // White background for the container
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Item Name: $itemName',
                          style: const TextStyle(fontSize: 18), // Adjusted font size
                        ),
                        Text(
                          'P.O No: $poNo',
                          style: const TextStyle(fontSize: 18), // Adjusted font size
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: articleLabelController,
                          decoration: const InputDecoration(
                            labelText: 'Article Label',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: _validateArticleLabel,
                          onFieldSubmitted: (_) {
                            // When Enter is pressed and there's no error, proceed
                            if (!isError) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ScanItem(
                                    scanData: {
                                      'itemName': itemName,
                                      'poNo': poNo,
                                      'lotNumber': lotNumberController.text,
                                      'content': articleLabelController.text,
                                      'qtyPerBox': qtyController.text,
                                      'operatorScanId': operatorScanId,
                                      'totalQty': totalQty,
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Error message
                        if (isError)
                          const Text(
                            'Wrong Article Label entered!',
                            style: TextStyle(color: Colors.red),
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: lotNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Lot Number',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !isError, // Disable if there's an error
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: qtyController,
                          decoration: const InputDecoration(
                            labelText: 'QTY per box',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !isError, // Disable if there's an error
                        ),
                        const SizedBox(height: 32),
                        // Centering the Proceed button
                        Center(
                          child: ElevatedButton(
                            onPressed: isError ? null : () async {  // Disable button when isError is true
                              // Save the article label data to database
                              await DatabaseHelper().insertArticleLabel({
                                'operatorScanId': operatorScanId,
                                'articleLabel': articleLabelController.text,
                                'lotNumber': lotNumberController.text,
                                'qtyPerBox': qtyController.text,
                                'content': articleLabelController.text,
                                'createdAt': DateTime.now().toIso8601String(),
                              });

                              // Navigate to ScanItem page
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ScanItem(
                                    scanData: {
                                      'itemName': itemName,
                                      'poNo': poNo,
                                      'lotNumber': lotNumberController.text,
                                      'content': articleLabelController.text,
                                      'qtyPerBox': qtyController.text,
                                      'operatorScanId': operatorScanId,
                                      'totalQty': totalQty,
                                    },
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isError ? Colors.grey : Colors.deepPurple, // Grey when disabled
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Proceed'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 