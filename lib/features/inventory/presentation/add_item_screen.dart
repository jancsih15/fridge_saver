import 'package:flutter/material.dart';

import '../data/open_food_facts_client.dart';
import '../domain/fridge_item.dart';
import 'barcode_scanner_screen.dart';

class AddItemInput {
  AddItemInput({
    required this.name,
    required this.quantity,
    required this.expirationDate,
    required this.location,
    this.barcode,
  });

  final String name;
  final String? barcode;
  final int quantity;
  final DateTime expirationDate;
  final StorageLocation location;
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    super.key,
    OpenFoodFactsClient? openFoodFactsClient,
    this.initialItem,
  }) : _openFoodFactsClient = openFoodFactsClient;

  final OpenFoodFactsClient? _openFoodFactsClient;
  final FridgeItem? initialItem;

  bool get isEditMode => initialItem != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  late final OpenFoodFactsClient _openFoodFactsClient;

  DateTime _expirationDate = DateTime.now().add(const Duration(days: 3));
  StorageLocation _location = StorageLocation.fridge;

  @override
  void initState() {
    super.initState();
    _openFoodFactsClient = widget._openFoodFactsClient ?? OpenFoodFactsClient();

    final initial = widget.initialItem;
    if (initial != null) {
      _nameController.text = initial.name;
      _barcodeController.text = initial.barcode ?? '';
      _quantityController.text = initial.quantity.toString();
      _expirationDate = initial.expirationDate;
      _location = initial.location;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        _expirationDate = picked;
      });
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _barcodeController.text = result;
    });
    _showInfo('Barcode scanned: $result');

    if (_nameController.text.trim().isNotEmpty) {
      _showInfo('Name already filled, skipped product lookup.');
      return;
    }

    final lookup = await _openFoodFactsClient.lookupProduct(result);
    if (!mounted) {
      return;
    }

    switch (lookup.status) {
      case OpenFoodFactsLookupStatus.found:
        setState(() {
          _nameController.text = lookup.productName!;
        });
        _showInfo('Product found: ${lookup.productName}');
        break;
      case OpenFoodFactsLookupStatus.notFound:
        _showInfo('No product found for this barcode.');
        break;
      case OpenFoodFactsLookupStatus.failed:
        _showInfo('Lookup failed. You can enter the product name manually.');
        break;
    }
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = int.parse(_quantityController.text);
    Navigator.of(context).pop(
      AddItemInput(
        name: _nameController.text,
        barcode: _barcodeController.text,
        quantity: quantity,
        expirationDate: _expirationDate,
        location: _location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Item' : 'Add Item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode (optional)',
                    suffixIcon: IconButton(
                      tooltip: 'Scan barcode',
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a number greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<StorageLocation>(
                  value: _location,
                  decoration: const InputDecoration(labelText: 'Location'),
                  items: StorageLocation.values
                      .map(
                        (location) => DropdownMenuItem(
                          value: location,
                          child: Text(location.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _location = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expiration date'),
                  subtitle: Text(
                    '${_expirationDate.year}-${_expirationDate.month.toString().padLeft(2, '0')}-${_expirationDate.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: OutlinedButton(
                    onPressed: _pickDate,
                    child: const Text('Pick date'),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.isEditMode ? 'Save Changes' : 'Save Item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
