import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling

class ArticleLabel extends StatefulWidget {
  final String itemName;
  final String poNo;

  const ArticleLabel({
    Key? key,
    required this.itemName,
    required this.poNo,
  }) : super(key: key);

  @override
  _ArticleLabelState createState() => _ArticleLabelState();
}

class _ArticleLabelState extends State<ArticleLabel> {
  final TextEditingController articleLabelController = TextEditingController();
  final TextEditingController lotNumberController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  bool isError = false; // Track if there's an error

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
                          'Item Name: ${widget.itemName}',
                          style: const TextStyle(fontSize: 18), // Adjusted font size
                        ),
                        Text(
                          'P.O No: ${widget.poNo}',
                          style: const TextStyle(fontSize: 18), // Adjusted font size
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: articleLabelController,
                          decoration: const InputDecoration(
                            labelText: 'Article Label',
                            border: OutlineInputBorder(),
                          ),
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
                            onPressed: () {
                              String articleLabel = articleLabelController.text;

                              // Check if the articleLabel is long enough
                              if (articleLabel.length >= 22) {
                                // Split the article label by spaces and take the first part
                                String firstPart = articleLabel.split(' ')[0];

                                // Extract Item Name starting after the first twelve digits
                                String extractedItemName = firstPart.substring(12); // Get everything after the first 12 digits

                                // Split the article label by spaces
                                List<String> parts = articleLabel.split(' ');

                                // Ensure there are enough parts to extract P.O No.
                                String extractedPoNo = '';
                                if (parts.length > 3) {
                                  extractedPoNo = parts[3].substring(0, 10); // First 10 digits after the third space
                                } else {
                                  // Handle the case where P.O No. cannot be extracted
                                  setState(() {
                                    isError = true; // Set error flag
                                  });
                                  return; // Exit early
                                }

                                // Validate against displayed values
                                print('Extracted Item Name: $extractedItemName');
                                print('Expected Item Name: ${widget.itemName}');
                                print('Extracted P.O No: $extractedPoNo');
                                print('Expected P.O No: ${widget.poNo}');

                                if (extractedItemName.trim() != widget.itemName || extractedPoNo != widget.poNo) {
                                  setState(() {
                                    isError = true; // Set error flag
                                  });
                                } else {
                                  setState(() {
                                    isError = false; // Clear error flag
                                  });
                                  // Extract values from the Article Label
                                  String articleLabel = articleLabelController.text;

                                  // Check if the Article Label is not empty
                                  if (articleLabel.isNotEmpty) {
                                    // Extract Item Name
                                    String itemName = articleLabel.substring(10, 22); // Extracting based on the position
                                    
                                    // Split the article label by spaces
                                    List<String> parts = articleLabel.split(' ');

                                    // Check if there are enough parts to extract the QTY per box
                                    String qtyPerBox = '';
                                    if (parts.length > 2) {
                                        // Get the part after the second space
                                        String qtyPart = parts.sublist(2).join(' '); // Join the remaining parts after the second space
                                        RegExp qtyRegExp = RegExp(r'(\d+)'); // Regex to find all digits
                                        Match? match = qtyRegExp.firstMatch(qtyPart);
                                        qtyPerBox = match != null ? match.group(1) ?? '' : ''; // Get the first match of digits
                                    }

                                    // Extract P.O No.
                                    String poNo = articleLabel.substring(0, 10); // First 10 characters

                                    // Extract Lot Number
                                    String lotNumber = parts.last; // Last part after space

                                    // Update the controllers with extracted values
                                    lotNumberController.text = lotNumber;
                                    qtyController.text = qtyPerBox;

                                    // Debugging output
                                    print('Item Name: $itemName');
                                    print('P.O No: $poNo');
                                    print('QTY per box: $qtyPerBox');
                                    print('Lot Number: $lotNumber');
                                  } else {
                                    print('Article Label is empty.');
                                  }
                                }
                              } else {
                                setState(() {
                                  isError = true; // Set error flag
                                });
                              }

                              // Update the state to reflect changes
                              (context as Element).markNeedsBuild();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple, // Match the color
                              foregroundColor: Colors.white, // Text color
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