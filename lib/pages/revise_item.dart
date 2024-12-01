import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'sublot_config.dart';
import '../utils/logout_helper.dart';
import '../widgets/code_container.dart';

class ReviseItem extends StatefulWidget {
  final Map<String, dynamic> item;

  const ReviseItem({super.key, required this.item});

  @override
  State<ReviseItem> createState() => _ReviseItemState();
}

class _ReviseItemState extends State<ReviseItem> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  String? _selectedRevision;
  String? _selectedCodeCount;
  List<CodeContainer> codeContainers = [];
  Map<int, String> selectedCategories = {};

  // Lists for dropdown items
  final List<String> _revisionNumbers = List.generate(10, (i) => (i + 1).toString());
  final List<String> _codeCounts = List.generate(20, (i) => (i + 1).toString());

  @override
  void initState() {
    super.initState();
    _itemNameController.text = widget.item['itemCode'] ?? '';
    _selectedRevision = widget.item['revision'];
    _selectedCodeCount = widget.item['codeCount'];
    // Initialize code containers based on the item data
    _initializeCodeContainers();
  }

  void _initializeCodeContainers() {
    final codes = widget.item['codes'] as List<Map<String, dynamic>>;
    setState(() {
      // Ensure all indices in selectedCategories are initialized
      for (int i = 0; i < codes.length; i++) {
        selectedCategories[i + 1] = codes[i]['category'] ?? 'Default Category';
      }

      codeContainers = List.generate(
        codes.length,
        (index) => CodeContainer(
          codeNumber: index + 1,
          selectedCategory: selectedCategories[index + 1]!,
          onCategoryChanged: (value) {
            setState(() {
              selectedCategories[index + 1] = value;
            });
          },
          labelController: TextEditingController(text: codes[index]['content']),
          hasSubLot: codes[index]['hasSubLot'] == 1,
        ),
      );
    });
  }

  void _updateCodeContainers(String? count) {
    if (count == null) return;

    setState(() {
      int numberOfCodes = int.parse(count);
      codeContainers = List.generate(
        numberOfCodes,
        (index) => CodeContainer(
          codeNumber: index + 1,
          selectedCategory: selectedCategories[index + 1] ?? 'Default Category',
          onCategoryChanged: (value) {
            setState(() {
              selectedCategories[index + 1] = value;
            });
          },
          labelController: TextEditingController(),
          hasSubLot: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    for (var container in codeContainers) {
      container.labelController.dispose();
    }
    super.dispose();
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
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/item-masterlist'),
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'Revise Item',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Card(
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _itemNameController,
                              decoration: const InputDecoration(
                                labelText: 'Item Name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => value!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),

                            DropdownButtonFormField<String>(
                              value: _selectedRevision,
                              decoration: const InputDecoration(
                                labelText: 'Rev No.',
                                border: OutlineInputBorder(),
                              ),
                              items: _revisionNumbers.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedRevision = newValue;
                                });
                              },
                              validator: (value) => value == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCodeCount,
                                    decoration: const InputDecoration(
                                      labelText: 'No. of Code',
                                      border: OutlineInputBorder(),
                                    ),
                                    hint: const Text('Select Number of Codes'),
                                    items: _codeCounts.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedCodeCount = newValue;
                                        _updateCodeContainers(newValue);
                                      });
                                    },
                                    validator: (value) => value == null ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                            ),

                            // Dynamic Code Containers
                            ...codeContainers,

                            const SizedBox(height: 32),

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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    // Gather data to update
                                    final updatedItem = {
                                      'itemCode': _itemNameController.text,
                                      'revision': _selectedRevision,
                                      'codeCount': _selectedCodeCount,
                                      'codes': codeContainers.map((container) {
                                        return {
                                          'category': container.selectedCategory,
                                          'content': container.labelController.text,
                                          'hasSubLot': false, // Adjust as needed
                                          'serialCount': '0', // Adjust as needed
                                        };
                                      }).toList(),
                                    };

                                    // Call the update method
                                    await DatabaseHelper().updateItem(widget.item['id'], updatedItem);

                                    // Optionally navigate back or show a success message
                                    Navigator.of(context).pop(); // Go back to the previous screen
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item updated successfully')),
                                    );
                                  }
                                },
                                child: const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
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