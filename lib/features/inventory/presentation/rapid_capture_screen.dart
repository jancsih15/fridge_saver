import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../data/barcode_lookup_models.dart';
import '../data/barcode_lookup_service.dart';
import '../domain/fridge_item.dart';
import 'barcode_value_parser.dart';
import 'inventory_controller.dart';

class RapidCaptureScreen extends StatefulWidget {
  const RapidCaptureScreen({super.key});

  @override
  State<RapidCaptureScreen> createState() => _RapidCaptureScreenState();
}

class _RapidCaptureScreenState extends State<RapidCaptureScreen> {
  String? _barcode;
  String? _name;
  bool _isLookingUp = false;

  final _quantityController = TextEditingController(text: '1');
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 3));
  StorageLocation _location = StorageLocation.fridge;

  late final BarcodeLookupService _lookupService;

  @override
  void initState() {
    super.initState();
    _lookupService = context.read<BarcodeLookupService>();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted || _isLookingUp) {
      return;
    }

    final barcode = pickFirstBarcodeValue(
      capture.barcodes.map((barcode) => barcode.rawValue),
    );
    if (barcode == null || barcode == _barcode) {
      return;
    }

    setState(() {
      _barcode = barcode;
      _name = null;
      _isLookingUp = true;
    });

    final lookup = await _lookupService.lookupProduct(barcode);
    if (!mounted || _barcode != barcode) {
      return;
    }

    setState(() {
      _isLookingUp = false;
      if (lookup.status == BarcodeLookupStatus.found) {
        _name = lookup.productName;
      } else {
        _name = 'Item $barcode';
      }
    });
  }

  Future<void> _saveAndContinue() async {
    final barcode = _barcode;
    final name = _name?.trim();
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (barcode == null || name == null || name.isEmpty) {
      return;
    }

    await context.read<InventoryController>().addItem(
      name: name,
      barcode: barcode,
      quantity: quantity < 1 ? 1 : quantity,
      expirationDate: _expirationDate,
      location: _location,
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved: $name')));

    setState(() {
      _barcode = null;
      _name = null;
      _isLookingUp = false;
      _quantityController.text = '1';
      _expirationDate = DateTime.now().add(const Duration(days: 3));
      _location = StorageLocation.fridge;
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameReady = _barcode != null && _name != null && !_isLookingUp;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapid Capture')),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: MobileScanner(
              onDetect: _onDetect,
              overlayBuilder: (context, constraints) {
                final size = constraints.biggest;
                final frameWidth = size.width * 0.72;
                final frameHeight = frameWidth * 0.55;
                return Stack(
                  children: [
                    Center(
                      child: Container(
                        width: frameWidth,
                        height: frameHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black54,
                        padding: const EdgeInsets.all(10),
                        child: const Text(
                          'Scan barcodes quickly and save in one tap',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _barcode == null
                  ? const Center(
                      child: Text(
                        'Scan your first item barcode to start rapid capture.',
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLookingUp
                              ? 'Looking up product...'
                              : (_name ?? 'Unknown item'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Barcode: $_barcode'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<StorageLocation>(
                                value: _location,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                ),
                                items: StorageLocation.values
                                    .map(
                                      (loc) => DropdownMenuItem(
                                        value: loc,
                                        child: Text(loc.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _location = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Expiration'),
                          subtitle: Text(
                            '${_expirationDate.year}-${_expirationDate.month.toString().padLeft(2, '0')}-${_expirationDate.day.toString().padLeft(2, '0')}',
                          ),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expirationDate,
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 5),
                            );
                            if (picked != null && mounted) {
                              setState(() => _expirationDate = picked);
                            }
                          },
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: frameReady ? _saveAndContinue : null,
                            icon: const Icon(Icons.flash_on),
                            label: const Text('Save item and keep scanning'),
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
