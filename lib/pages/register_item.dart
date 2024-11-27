import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';

class RegisterItem extends StatefulWidget {
  const RegisterItem({super.key});

  @override
  State<RegisterItem> createState() => _RegisterItemState();
}

class _RegisterItemState extends State<RegisterItem> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  String? _selectedRevision;
  String? _selectedCodeCount;
  List<CodeContainer> codeContainers = [];

  // Lists for dropdown items
  final List<String> _revisionNumbers = List.generate(10, (i) => (i + 1).toString());
  final List<String> _codeCounts = List.generate(20, (i) => (i + 1).toString());

  // In the _RegisterItemState class, add this to track categories:
  Map<int, String> selectedCategories = {};

  void _updateCodeContainers(String? count) {
    if (count == null) return;
    
    setState(() {
      int numberOfCodes = int.parse(count);
      codeContainers = List.generate(
        numberOfCodes,
        (index) => CodeContainer(
          codeNumber: index + 1,
          selectedCategory: selectedCategories[index + 1],
          onCategoryChanged: (value) {
            setState(() {
              selectedCategories[index + 1] = value;
            });
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
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

                  const Center(
                    child: Text(
                      'Register New Item',
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

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedRevision,
                                    decoration: const InputDecoration(
                                      labelText: 'Rev No.',
                                      border: OutlineInputBorder(),
                                    ),
                                    hint: const Text('Select Revision Number'),
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
                                ),
                                const SizedBox(width: 20),
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
                              ],
                            ),
                            const SizedBox(height: 20),

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
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    // Handle form submission
                                  }
                                },
                                child: const Text('Next'),
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

// Create a separate widget for the code container
class CodeContainer extends StatelessWidget {
  final int codeNumber;
  final String? selectedCategory;
  final Function(String) onCategoryChanged;

  const CodeContainer({
    Key? key,
    required this.codeNumber,
    this.selectedCategory,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Code $codeNumber',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'Counting',
                        groupValue: selectedCategory,
                        onChanged: (value) => onCategoryChanged(value!),
                      ),
                      const Text('Counting'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'Non-Counting',
                        groupValue: selectedCategory,
                        onChanged: (value) => onCategoryChanged(value!),
                      ),
                      const Text('Non-Counting'),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Label Content $codeNumber',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 