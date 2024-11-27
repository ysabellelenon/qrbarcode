import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'sublot_config.dart';

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
  Map<int, String> selectedCategories = {};

  // Lists for dropdown items
  final List<String> _revisionNumbers = List.generate(10, (i) => (i + 1).toString());
  final List<String> _codeCounts = List.generate(20, (i) => (i + 1).toString());

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
          labelController: TextEditingController(),
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
                                    final countingCodes = selectedCategories.entries
                                        .where((entry) => entry.value == 'Counting')
                                        .map((entry) => {
                                              'code': entry.key.toString(),
                                              'content': '',
                                            })
                                        .toList();

                                    if (countingCodes.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SublotConfig(
                                            itemName: _itemNameController.text,
                                            countingCodes: countingCodes,
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('At least one code must have Counting category'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
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

// Update the CodeContainer to be stateful
class CodeContainer extends StatefulWidget {
  final int codeNumber;
  final String? selectedCategory;
  final Function(String) onCategoryChanged;
  final TextEditingController labelController;

  const CodeContainer({
    Key? key,
    required this.codeNumber,
    this.selectedCategory,
    required this.onCategoryChanged,
    required this.labelController,
  }) : super(key: key);

  @override
  State<CodeContainer> createState() => _CodeContainerState();
}

class _CodeContainerState extends State<CodeContainer> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
  }

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
            'Code ${widget.codeNumber}',
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
                  Text('Category ${widget.codeNumber}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCategoryButton('Counting'),
                      const SizedBox(width: 8),
                      _buildCategoryButton('Non-Counting'),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: widget.labelController,
                  decoration: InputDecoration(
                    labelText: 'Label Content ${widget.codeNumber}',
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

  Widget _buildCategoryButton(String category) {
    final isSelected = _selectedCategory == category;
    
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedCategory = category;
        });
        widget.onCategoryChanged(category);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.deepPurple : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        side: BorderSide(
          color: isSelected ? Colors.deepPurple : Colors.grey,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(category),
    );
  }
} 