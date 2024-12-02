import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling

class ArticleLabel extends StatelessWidget {
  final String itemName;
  final String poNo;

  const ArticleLabel({
    Key? key,
    required this.itemName,
    required this.poNo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController articleLabelController = TextEditingController();
    final TextEditingController lotNumberController = TextEditingController();
    final TextEditingController qtyController = TextEditingController();

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
                    padding: const EdgeInsets.all(30), // Increased padding
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
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: lotNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Lot Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: qtyController,
                          decoration: const InputDecoration(
                            labelText: 'QTY per box',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 32),
                        // Centering the Proceed button
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              // Extract values from the Article Label
                              String articleLabel = articleLabelController.text;

                              // Check if the Article Label is not empty
                              if (articleLabel.isNotEmpty) {
                                // Extract Item Name
                                String itemName = articleLabel.substring(10, 22); // Extracting based on the position
                                
                                // Extract QTY per box
                                String qtyPart = articleLabel.split(' ')[1]; // Get the second part after splitting
                                String qtyPerBox = qtyPart.substring(2); // Get the part after the first two characters

                                // Extract P.O No.
                                String poNo = articleLabel.substring(0, 10); // First 10 characters

                                // Extract Lot Number
                                String lotNumber = articleLabel.split(' ').last; // Last part after space

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