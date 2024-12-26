import 'package:flutter/material.dart';

class CodeContainer extends StatefulWidget {
  final int codeNumber;
  final String? selectedCategory;
  final Function(String) onCategoryChanged;
  final TextEditingController labelController;
  final bool hasSubLot;

  const CodeContainer({
    Key? key,
    required this.codeNumber,
    this.selectedCategory,
    required this.onCategoryChanged,
    required this.labelController,
    required this.hasSubLot,
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
        borderRadius: BorderRadius.circular(8),
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
            children: [
              _buildCategoryButton('Counting'),
              const SizedBox(width: 8),
              _buildCategoryButton('Non-Counting'),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: widget.labelController,
                  decoration: InputDecoration(
                    labelText: 'Label Content ${widget.codeNumber}',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Required' : null,
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