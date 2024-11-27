import 'package:flutter/material.dart';
import '../database_helper.dart';

class NewAccount extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lineNoController = TextEditingController();
  final _sectionController = TextEditingController();

  void _saveUser(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      final user = {
        'lastName': _lastNameController.text,
        'firstName': _firstNameController.text,
        'lineNo': _lineNoController.text,
        'section': _sectionController.text,
      };
      await DatabaseHelper().insertUser(user);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) => value!.isEmpty ? 'Enter last name' : null,
              ),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) => value!.isEmpty ? 'Enter first name' : null,
              ),
              TextFormField(
                controller: _lineNoController,
                decoration: const InputDecoration(labelText: 'Line No'),
                validator: (value) => value!.isEmpty ? 'Enter line no' : null,
              ),
              TextFormField(
                controller: _sectionController,
                decoration: const InputDecoration(labelText: 'Section'),
                validator: (value) => value!.isEmpty ? 'Enter section' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _saveUser(context),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 