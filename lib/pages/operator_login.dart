import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling

class OperatorLogin extends StatefulWidget {
  const OperatorLogin({super.key});

  @override
  State<OperatorLogin> createState() => _OperatorLoginState();
}

class _OperatorLoginState extends State<OperatorLogin> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _poNoController = TextEditingController();
  final _qtyController = TextEditingController();

  @override
  void dispose() {
    _itemNameController.dispose();
    _poNoController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      // Handle form submission logic here
      final itemName = _itemNameController.text;
      final poNo = _poNoController.text;
      final qty = _qtyController.text;

      // Example: Show a snackbar with the input values
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item: $itemName, P.O No: $poNo, Qty: $qty'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Operator Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _poNoController,
                    decoration: const InputDecoration(
                      labelText: 'P.O No.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Total QTY',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Ok'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 