import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../data/barcode_lookup_models.dart';
import '../data/rapid_capture_preferences_repository.dart';
import '../data/barcode_lookup_service.dart';
import '../domain/fridge_item.dart';
import 'barcode_value_parser.dart';
import 'expiry_date_parser.dart';
import 'inventory_controller.dart';

class RapidCaptureScreen extends StatefulWidget {
  const RapidCaptureScreen({super.key});

  @override
  State<RapidCaptureScreen> createState() => _RapidCaptureScreenState();
}

class _RapidDraft {
  _RapidDraft({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.expirationDate,
    required this.location,
  });

  final String barcode;
  String name;
  int quantity;
  DateTime expirationDate;
  StorageLocation location;
}

class _RapidCaptureScreenState extends State<RapidCaptureScreen> {
  late final BarcodeLookupService _lookupService;
  late final RapidCapturePreferencesRepository _prefsRepository;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _imagePicker = ImagePicker();
  final List<_RapidDraft> _queue = [];
  final Set<String> _activeLookups = <String>{};

  String? _lastBarcode;
  DateTime? _lastBarcodeAt;
  bool _isSaving = false;
  StorageLocation _defaultLocation = StorageLocation.fridge;

  @override
  void initState() {
    super.initState();
    _lookupService = context.read<BarcodeLookupService>();
    _prefsRepository = RapidCapturePreferencesRepository();
    _loadDefaults();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final location = await _prefsRepository.loadLastLocation();
    if (!mounted) {
      return;
    }
    setState(() => _defaultLocation = location);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!mounted || _isSaving) {
      return;
    }

    final barcode = pickFirstBarcodeValue(
      capture.barcodes.map((barcode) => barcode.rawValue),
    );
    if (barcode == null) {
      return;
    }

    final now = DateTime.now();
    if (_lastBarcode == barcode &&
        _lastBarcodeAt != null &&
        now.difference(_lastBarcodeAt!).inMilliseconds < 1200) {
      return;
    }

    _lastBarcode = barcode;
    _lastBarcodeAt = now;

    setState(() {
      _queue.insert(
        0,
        _RapidDraft(
          barcode: barcode,
          name: 'Item $barcode',
          quantity: 1,
          expirationDate: DateTime.now().add(const Duration(days: 3)),
          location: _defaultLocation,
        ),
      );
    });
    _applyRememberedQuantity(index: 0, barcode: barcode);

    if (_activeLookups.contains(barcode)) {
      return;
    }
    _activeLookups.add(barcode);
    final lookup = await _lookupService.lookupProduct(barcode);
    _activeLookups.remove(barcode);
    if (!mounted || lookup.status != BarcodeLookupStatus.found) {
      return;
    }

    setState(() {
      for (final draft in _queue) {
        if (draft.barcode == barcode && draft.name == 'Item $barcode') {
          draft.name = lookup.productName!;
          break;
        }
      }
    });
  }

  Future<void> _applyRememberedQuantity({
    required int index,
    required String barcode,
  }) async {
    final remembered = await _prefsRepository.loadRememberedQuantity(barcode);
    if (remembered == null || !mounted || index >= _queue.length) {
      return;
    }
    if (_queue[index].barcode != barcode) {
      return;
    }
    setState(() {
      _queue[index].quantity = remembered;
    });
  }

  Future<void> _saveAll() async {
    if (_queue.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    final controller = context.read<InventoryController>();
    for (final draft in _queue) {
      await controller.addItem(
        name: draft.name,
        barcode: draft.barcode,
        quantity: draft.quantity < 1 ? 1 : draft.quantity,
        expirationDate: draft.expirationDate,
        location: draft.location,
      );
      await _prefsRepository.saveRememberedQuantity(
        draft.barcode,
        draft.quantity < 1 ? 1 : draft.quantity,
      );
      await _prefsRepository.saveLastLocation(draft.location);
      _defaultLocation = draft.location;
    }
    if (!mounted) {
      return;
    }

    final count = _queue.length;
    setState(() {
      _queue.clear();
      _isSaving = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved $count queued items.')));
  }

  Future<void> _captureExpiryForIndex(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }

    final image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image == null || !mounted) {
      return;
    }

    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      final analysis = analyzeExpirationDateText(
        recognized.text,
        now: DateTime.now(),
      );
      if (!mounted) {
        return;
      }

      if (analysis.candidates.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('No date detected from photo.')),
          );
        return;
      }

      final selected = await _selectDateCandidate(analysis.candidates);
      if (selected == null || !mounted) {
        return;
      }

      setState(() {
        _queue[index].expirationDate = selected;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Updated expiry: ${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Date scan failed. Try again.')),
        );
    }
  }

  Future<DateTime?> _selectDateCandidate(List<DateTime> candidates) {
    final visible = candidates.take(6).toList(growable: false);
    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick detected expiry date',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: visible.map((date) {
                    final label =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    return ActionChip(
                      label: Text(label),
                      onPressed: () => Navigator.of(context).pop(date),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        child: Text(
                          _isSaving
                              ? 'Saving queue...'
                              : 'Scan continuously, then save all at once',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Queue (${_queue.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _queue.isEmpty
                            ? null
                            : () => setState(() => _queue.clear()),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _queue.isEmpty
                        ? const Center(
                            child: Text(
                              'Start scanning items. They will be queued here.',
                            ),
                          )
                        : ListView.separated(
                            itemCount: _queue.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _queue[index];
                              return ListTile(
                                title: Text(item.name),
                                subtitle: Text(
                                  '${item.barcode} - Qty ${item.quantity} - ${item.location.name}\nExp: ${item.expirationDate.year}-${item.expirationDate.month.toString().padLeft(2, '0')}-${item.expirationDate.day.toString().padLeft(2, '0')}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PopupMenuButton<int>(
                                      tooltip: 'Quick quantity',
                                      onSelected: (value) =>
                                          setState(() => item.quantity = value),
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 1,
                                          child: Text('Qty 1'),
                                        ),
                                        PopupMenuItem(
                                          value: 2,
                                          child: Text('Qty 2'),
                                        ),
                                        PopupMenuItem(
                                          value: 6,
                                          child: Text('Qty 6'),
                                        ),
                                      ],
                                      icon: const Icon(Icons.flash_on_outlined),
                                    ),
                                    PopupMenuButton<StorageLocation>(
                                      tooltip: 'Change location',
                                      onSelected: (value) => setState(() {
                                        item.location = value;
                                        _defaultLocation = value;
                                      }),
                                      itemBuilder: (context) => StorageLocation
                                          .values
                                          .map(
                                            (loc) => PopupMenuItem(
                                              value: loc,
                                              child: Text(loc.name),
                                            ),
                                          )
                                          .toList(growable: false),
                                      icon: const Icon(Icons.kitchen_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Scan expiry photo',
                                      onPressed: () =>
                                          _captureExpiryForIndex(index),
                                      icon: const Icon(
                                        Icons.document_scanner_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: item.quantity > 1
                                          ? () => setState(
                                              () => item.quantity -= 1,
                                            )
                                          : null,
                                      icon: const Icon(Icons.remove_circle),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          setState(() => item.quantity += 1),
                                      icon: const Icon(Icons.add_circle),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() => _queue.removeAt(index));
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _queue.isEmpty || _isSaving ? null : _saveAll,
                      icon: const Icon(Icons.save),
                      label: const Text('Save all queued items'),
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
