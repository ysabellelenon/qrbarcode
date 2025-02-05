import 'package:flutter/material.dart';
import 'package:qrbarcode/pages/item_masterlist.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'sublot_config.dart';
import '../utils/logout_helper.dart';
import '../widgets/code_container.dart';
import 'revise_sublot.dart';

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
  final List<String> _revisionNumbers =
      List.generate(10, (i) => (i + 1).toString());
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
    final codes = widget.item['codes'] as List<dynamic>;
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
          serialCount: codes[index]['serialCount'] ?? '0',
        ),
      );
    });
  }

  void _updateCodeContainers(String? count) {
    if (count == null) return;

    setState(() {
      int numberOfCodes = int.parse(count);
      List<CodeContainer> newContainers = [];

      // Create new containers while preserving existing data
      for (int i = 0; i < numberOfCodes; i++) {
        if (i < codeContainers.length) {
          // Preserve existing container data
          newContainers.add(codeContainers[i]);
        } else {
          // Add new container with default values
          newContainers.add(
            CodeContainer(
              codeNumber: i + 1,
              selectedCategory: selectedCategories[i + 1] ?? 'Default Category',
              onCategoryChanged: (value) {
                setState(() {
                  selectedCategories[i + 1] = value;
                });
              },
              labelController: TextEditingController(),
              hasSubLot: false,
            ),
          );
        }
      }
      codeContainers = newContainers;
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
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ItemMasterlist(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            const begin = Offset(-1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOut;
                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));
                            return SlideTransition(
                              position: animation.drive(tween),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _itemNameController,
                              decoration: const InputDecoration(
                                labelText: 'Item Name',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 20),
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 24),

                            DropdownButtonFormField<String>(
                              value: _selectedRevision,
                              decoration: const InputDecoration(
                                labelText: 'Rev No.',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 20),
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
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCodeCount,
                                    decoration: const InputDecoration(
                                      labelText: 'No. of Code',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 20),
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
                                    validator: (value) =>
                                        value == null ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Dynamic Code Containers
                            ...codeContainers
                                .map((container) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 24),
                                      child: container,
                                    ))
                                .toList(),

                            const SizedBox(height: 16),

                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _onProceed(),
                                child: const Text('Proceed'),
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

  void _onProceed() {
    if (_formKey.currentState!.validate()) {
      bool allCodesValid = true;

      for (var container in codeContainers) {
        String? category = selectedCategories[container.codeNumber];
        if (category == null ||
            (category != 'Counting' && category != 'Non-Counting')) {
          allCodesValid = false;
          break;
        }
      }

      if (!allCodesValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please select "Counting" or "Non-Counting" for each code.'),
          ),
        );
        return;
      }

      final uniqueCategories =
          selectedCategories.values.toSet();
      if (uniqueCategories.length > 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Inconsistent Categories'),
            content: const Text(
                'All codes must have the same category. Please ensure all categories are consistent before proceeding.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Gather the codes data
      final allCodes = codeContainers.map((container) {
        return {
          'category': container.selectedCategory,
          'content': container.labelController.text,
          'hasSubLot': container.hasSubLot,
          'serialCount': container.serialCount,
        };
      }).toList();

      // Get only counting codes
      final countingCodes = allCodes
          .where((code) => code['category'] == 'Counting')
          .map((code) => {
                'category': code['category'].toString(),
                'content': code['content'].toString(),
              })
          .toList();

      if (countingCodes.isNotEmpty) {
        // Navigate to ReviseSublot if there are counting codes
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviseSublot(
              itemId: widget.item['id'],
              itemName: _itemNameController.text,
              revision: _selectedRevision!,
              countingCodes:
                  countingCodes as List<Map<String, String>>,
              allCodes: allCodes,
            ),
          ),
        );
      } else {
        // If no counting codes, update directly
        _updateItem(allCodes);
      }
    }
  }

  void _updateItem(List<Map<String, dynamic>> codes) async {
    try {
      final now = DateTime.now().toIso8601String();
      // Prepare the complete updated item data
      final updatedItem = {
        'itemCode': _itemNameController.text,
        'revision': _selectedRevision,
        'codeCount': _selectedCodeCount,
        'codes': codes
            .map((code) => {
                  'category': code['category'],
                  'content': code['content'],
                  'hasSubLot': code['hasSubLot'] ? 1 : 0,
                  'serialCount': code['serialCount'] ?? '0',
                  'isActive': 1,
                  'lastUpdated': now,
                })
            .toList(),
        'isActive': 1,
        'lastUpdated': now,
      };

      // Update the item in the database
      await DatabaseHelper().updateItem(widget.item['id'], updatedItem);

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
}
