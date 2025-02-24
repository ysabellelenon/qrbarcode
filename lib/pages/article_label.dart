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
  final bool hideBackButton;

  const ArticleLabel({
    Key? key,
    this.itemName,
    this.poNo,
    this.operatorScanId,
    this.totalQty,
    this.resumeData,
    this.hideBackButton = false,
  }) : super(key: key);

  @override
  _ArticleLabelState createState() => _ArticleLabelState();
}

class _ArticleLabelState extends State<ArticleLabel> {
  final TextEditingController articleLabelController = TextEditingController();
  final TextEditingController lotNumberController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  bool isError = false; // Track if there's an error

  // Add FocusNode for the Article Label field
  final FocusNode _articleLabelFocus = FocusNode();

  String get itemName =>
      widget.resumeData?['itemName'] ?? widget.itemName ?? '';
  String get poNo => widget.resumeData?['poNo'] ?? widget.poNo ?? '';
  int get operatorScanId =>
      widget.resumeData?['operatorScanId'] ?? widget.operatorScanId ?? 0;
  int get totalQty => widget.resumeData?['totalQty'] ?? widget.totalQty ?? 0;

  void _validateArticleLabel(String articleLabel) {
    // If articleLabel is empty, set error state and return early
    if (articleLabel.isEmpty) {
      setState(() {
        isError = true;
        lotNumberController.clear(); // Clear the fields
        qtyController.clear();
      });
      return;
    }

    print('\nArticle Label Validation:');
    print('Original Input: $articleLabel');

    // Remove extra spaces and ensure consistent spacing
    String cleanLabel = articleLabel.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Extract item code (starts after first 12 characters until R-Pb)
    String extractedItemName = '';
    int rPbIndex = cleanLabel.indexOf("R-Pb");
    if (cleanLabel.length >= 12 && rPbIndex != -1) {
      extractedItemName = cleanLabel.substring(12, rPbIndex).trim();
    }

    // Extract QTY - find pattern of 2 letters followed by numbers after "R-Pb"
    String qtyPerBox = "";
    if (rPbIndex != -1) {
      // Look for pattern of 2 letters followed by numbers after R-Pb
      RegExp qtyRegExp = RegExp(r'[A-Z]{2}(\d+)');
      Match? qtyMatch = qtyRegExp.firstMatch(cleanLabel.substring(rPbIndex));
      if (qtyMatch != null) {
        qtyPerBox = qtyMatch.group(1) ?? ""; // Get just the number part
      }
    }

    // Extract lot number (last part)
    String lotNumber = cleanLabel.split(' ').last;

    // Extract PO number (10 digits before sequence number)
    RegExp poRegExp = RegExp(r'(\d{10})');
    Match? poMatch = poRegExp.firstMatch(cleanLabel);
    String extractedPoNo = poMatch?.group(1) ?? '';

    print('Extracted Item Name: $extractedItemName');
    print('Extracted PO No: $extractedPoNo');
    print('QTY per box: $qtyPerBox');
    print('Lot Number: $lotNumber');

    if (extractedItemName.trim() != itemName || extractedPoNo != poNo) {
      setState(() {
        isError = true;
        print('Validation Failed:');
        print('Expected Item Name: $itemName, Got: ${extractedItemName.trim()}');
        print('Expected PO No: $poNo, Got: $extractedPoNo');
      });
    } else {
      setState(() {
        isError = false;
        lotNumberController.text = lotNumber;
        qtyController.text = qtyPerBox;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Request focus for the article label field after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_articleLabelFocus);
    });
  }

  @override
  void dispose() {
    // Clean up the focus node when the widget is disposed
    _articleLabelFocus.dispose();
    articleLabelController.dispose();
    lotNumberController.dispose();
    qtyController.dispose();
    super.dispose();
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
                const SelectableText(
                  'QR Barcode System',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),

          // Conditionally show Back Button
          if (!widget.hideBackButton) ...[
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
          ],
          const SizedBox(height: 20),

          // Heading
          Center(
            child: SelectableText(
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
                    borderRadius: kBorderRadiusSmallAll,
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
                        SelectableText(
                          'Item Name: $itemName',
                          style: const TextStyle(fontSize: 18),
                        ),
                        SelectableText(
                          'P.O No: $poNo',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: articleLabelController,
                          focusNode: _articleLabelFocus,
                          decoration: InputDecoration(
                            labelText: 'Article Label',
                            border: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                              borderSide: const BorderSide(color: kPrimaryColor),
                            ),
                          ),
                          onChanged: _validateArticleLabel,
                        ),
                        const SizedBox(height: 16),
                        // Error message
                        if (isError)
                          Text(
                            articleLabelController.text.isEmpty 
                              ? 'Please scan or enter Article Label'
                              : 'Wrong Article Label entered!',
                            style: TextStyle(color: Colors.red),
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: lotNumberController,
                          decoration: InputDecoration(
                            labelText: 'Lot Number',
                            border: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                              borderSide: const BorderSide(color: kPrimaryColor),
                            ),
                          ),
                          enabled: !isError, // Disable if there's an error
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: qtyController,
                          decoration: InputDecoration(
                            labelText: 'QTY per box',
                            border: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: kBorderRadiusSmallAll,
                              borderSide: const BorderSide(color: kPrimaryColor),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !isError, // Disable if there's an error
                          readOnly: true,
                        ),
                        const SizedBox(height: 32),
                        // Centering the Proceed button
                        Center(
                          child: ElevatedButton(
                            onPressed: (isError || articleLabelController.text.isEmpty)
                                ? null
                                : () async {
                                    print('\n=== Article Label Processing ===');
                                    print('Item Name: $itemName');
                                    print('Starting database query...');
                                    
                                    // Get the item details from database to get the registered label content
                                    final items = await DatabaseHelper().getItems();
                                    print('Retrieved ${items.length} items from database');
                                    
                                    final matchingItem = items.firstWhere(
                                      (item) {
                                        print('Checking item: ${item['itemCode']} against $itemName');
                                        return item['itemCode'] == itemName;
                                      },
                                      orElse: () => <String, dynamic>{},
                                    );
                                    print('Found matching item: ${matchingItem.isNotEmpty}');
                                    print('Matching item details: $matchingItem');

                                    String labelContent = '';
                                    if (matchingItem.isNotEmpty) {
                                      final codes = matchingItem['codes'] as List;
                                      print('Found codes: $codes');
                                      
                                      // First try to find Counting code
                                      final countingCode = codes.firstWhere(
                                        (code) => code['category'] == 'Counting',
                                        orElse: () => <String, dynamic>{},
                                      );
                                      
                                      // If no Counting code, look for Non-Counting code
                                      final nonCountingCode = codes.firstWhere(
                                        (code) => code['category'] == 'Non-Counting',
                                        orElse: () => <String, dynamic>{},
                                      );
                                      
                                      String baseContent = '';
                                      if (countingCode.isNotEmpty) {
                                        baseContent = countingCode['content'] ?? '';
                                        print('Retrieved Base Label Content (Counting): $baseContent');
                                      } else if (nonCountingCode.isNotEmpty) {
                                        baseContent = nonCountingCode['content'] ?? '';
                                        print('Retrieved Base Label Content (Non-Counting): $baseContent');
                                      }
                                      
                                      // Combine with lot number based on category
                                      if (countingCode.isNotEmpty) {
                                        // For Counting items, format lot number
                                        String formattedLotNumber = lotNumberController.text.contains('-') 
                                          ? lotNumberController.text.split('-').join('')
                                          : lotNumberController.text;
                                        labelContent = baseContent + formattedLotNumber;
                                      } else if (nonCountingCode.isNotEmpty) {
                                        // For Non-Counting items, use original lot number
                                        labelContent = baseContent + lotNumberController.text;
                                      }
                                      
                                      print('Base Content: $baseContent');
                                      print('Lot Number: ${lotNumberController.text}');
                                      print('Final Content to be passed: $labelContent');
                                    }

                                    // Save the article label data to database
                                    await DatabaseHelper().insertArticleLabel({
                                      'operatorScanId': operatorScanId,
                                      'articleLabel': articleLabelController.text,
                                      'lotNumber': lotNumberController.text,
                                      'qtyPerBox': qtyController.text,
                                      'content': labelContent,  // Use the combined content
                                      'createdAt': DateTime.now().toIso8601String(),
                                    });

                                    print('\n=== Starting New Scanning Session ===');
                                    print('Item Name: $itemName');
                                    print('PO No: $poNo');
                                    print('Lot Number: ${lotNumberController.text}');
                                    print('Content: $labelContent');
                                    print('QTY per box: ${qtyController.text}');
                                    print('Total QTY: $totalQty');

                                    // Navigate to ScanItem page with historical data preserved
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => ScanItem(
                                          scanData: {
                                            'itemName': itemName,
                                            'poNo': poNo,
                                            'lotNumber': lotNumberController.text,
                                            'content': labelContent,  // Use the combined content
                                            'qtyPerBox': qtyController.text,
                                            'operatorScanId': operatorScanId,
                                            'totalQty': totalQty,
                                            'preserveHistory': true,  // Add this flag
                                          },
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (isError || articleLabelController.text.isEmpty)
                                  ? Colors.grey
                                  : Colors.deepPurple, // Grey when disabled
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: kBorderRadiusSmallAll,
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
