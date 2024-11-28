import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'sublot_config.dart';
import 'review_item.dart';
import '../utils/logout_helper.dart';

class ReviseItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const ReviseItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Use the item data as needed
    return Scaffold(
      appBar: AppBar(title: const Text('Revise Item')),
      body: Center(
        child: Text('Item Code: ${item['itemCode']}'),
      ),
    );
  }
}

// CodeContainer remains the same as in register_item.dart
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