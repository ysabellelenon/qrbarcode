import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'sublot_config.dart';
import 'review_item.dart';
import '../utils/logout_helper.dart';
import '../widgets/code_container.dart';

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

  final List<String> _revisionNumbers =
      List.generate(10, (i) => (i + 1).toString());
  final List<String> _codeCounts = List.generate(20, (i) => (i + 1).toString());

  @override
  void initState() {
    super.initState();
    _selectedRevision = '1';
    _selectedCodeCount = '1';
    _updateCodeContainers('1');
  }

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
          hasSubLot: false,
        ),
      );
    });
  }

  void _handleSubmit() {
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

      // Add category consistency check
      final uniqueCategories = selectedCategories.values.toSet();
      if (uniqueCategories.length > 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: kBorderRadiusSmallAll,
            ),
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

      final allCodes = codeContainers
          .map((container) => {
                'category': selectedCategories[container.codeNumber] ?? '',
                'content': container.labelController.text,
                'hasSubLot': false,
                'serialCount': '0',
              })
          .toList();

      final countingCodes = allCodes
          .where((code) => code['category'] == 'Counting')
          .map((code) => {
                'category': code['category'].toString(),
                'content': code['content'].toString(),
              })
          .toList();

      if (countingCodes.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SublotConfig(
              itemName: _itemNameController.text,
              countingCodes: countingCodes as List<Map<String, String>>,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewItem(
              itemName: _itemNameController.text,
              revision: _selectedRevision!,
              codeCount: allCodes.length,
              codes: allCodes,
            ),
          ),
        );
      }
    }
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
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/item-masterlist'),
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
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Card(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: kBorderRadiusSmallAll,
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
                                  decoration: InputDecoration(
                                    labelText: 'Item Name',
                                    border: OutlineInputBorder(
                                      borderRadius: kBorderRadiusSmallAll,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: kBorderRadiusSmallAll,
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: kBorderRadiusSmallAll,
                                      borderSide: const BorderSide(
                                          color: kPrimaryColor),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value!.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedRevision,
                                        decoration: InputDecoration(
                                          labelText: 'Rev No.',
                                          border: OutlineInputBorder(
                                            borderRadius: kBorderRadiusSmallAll,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: kBorderRadiusSmallAll,
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: kBorderRadiusSmallAll,
                                            borderSide: const BorderSide(
                                                color: kPrimaryColor),
                                          ),
                                        ),
                                        hint: const Text(
                                            'Select Revision Number'),
                                        items: _revisionNumbers
                                            .map((String value) {
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
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedCodeCount,
                                        decoration: InputDecoration(
                                          labelText: 'No. of Code',
                                          border: OutlineInputBorder(
                                            borderRadius: kBorderRadiusSmallAll,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: kBorderRadiusSmallAll,
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: kBorderRadiusSmallAll,
                                            borderSide: const BorderSide(
                                                color: kPrimaryColor),
                                          ),
                                        ),
                                        hint: const Text(
                                            'Select Number of Codes'),
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
                                const SizedBox(height: 20),

                                // Dynamic Code Containers
                                ...codeContainers,

                                const SizedBox(height: 32),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: _handleSubmit,
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
                                    child: const Text('Next'),
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
            ),
          ),
        ],
      ),
    );
  }
}
