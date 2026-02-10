import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ai_expiry_date_client.dart';
import '../data/open_food_facts_client.dart';
import '../domain/fridge_item.dart';
import 'barcode_scanner_screen.dart';
import 'expiry_date_parser.dart';

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

class _DateSuggestionSheetResult {
  const _DateSuggestionSheetResult({this.date, this.requestAi = false});

  final DateTime? date;
  final bool requestAi;
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    super.key,
    OpenFoodFactsClient? openFoodFactsClient,
    AiExpiryDateClient? aiExpiryDateClient,
    this.initialItem,
  }) : _openFoodFactsClient = openFoodFactsClient,
       _aiExpiryDateClient = aiExpiryDateClient;

  final OpenFoodFactsClient? _openFoodFactsClient;
  final AiExpiryDateClient? _aiExpiryDateClient;
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

  final _imagePicker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  late final OpenFoodFactsClient _openFoodFactsClient;
  late final AiExpiryDateClient _aiExpiryDateClient;

  DateTime _expirationDate = DateTime.now().add(const Duration(days: 3));
  StorageLocation _location = StorageLocation.fridge;

  @override
  void initState() {
    super.initState();
    _openFoodFactsClient = widget._openFoodFactsClient ?? OpenFoodFactsClient();
    _aiExpiryDateClient = widget._aiExpiryDateClient ?? AiExpiryDateClient();

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
    _textRecognizer.close();
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

  Future<void> _scanExpirationDate() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image == null || !mounted) {
        return;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _textRecognizer.processImage(inputImage);
      final localAnalysis = analyzeExpirationDateText(
        recognized.text,
        now: DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      if (localAnalysis.candidates.isNotEmpty) {
        final ocrSelection = await _showDateSuggestionSheet(
          localAnalysis,
          title: 'OCR Date Suggestions',
          allowTryAi: _aiExpiryDateClient.isEnabled,
        );
        if (ocrSelection == null || !mounted) {
          _showInfo('Date scan canceled. (OCR only)');
          return;
        }

        if (!ocrSelection.requestAi && ocrSelection.date != null) {
          setState(() {
            _expirationDate = ocrSelection.date!;
          });
          _showInfo(
            'Expiration set to ${_formatDate(ocrSelection.date!)} (OCR)',
          );
          return;
        }
      }

      final aiResult = await _resolveAiSuggestion(
        ocrText: recognized.text,
        image: image,
      );
      final analysis = _mergeWithAiSuggestion(localAnalysis, aiResult.date);

      if (!mounted) {
        return;
      }

      if (analysis.candidates.isEmpty) {
        _showInfo(
          'No valid expiration date detected. Please pick manually. (${_aiDebugLabelWithSource(aiResult)})',
        );
        return;
      }

      final aiSelection = await _showDateSuggestionSheet(
        analysis,
        title: 'AI Date Suggestions',
      );
      if (aiSelection == null || aiSelection.date == null || !mounted) {
        _showInfo('Date scan canceled. (${_aiDebugLabelWithSource(aiResult)})');
        return;
      }

      setState(() {
        _expirationDate = aiSelection.date!;
      });
      _showInfo(
        'Expiration set to ${_formatDate(aiSelection.date!)} (${_aiDebugLabelWithSource(aiResult)})',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showInfo('Could not process image for date OCR. Please pick manually.');
    }
  }

  Future<AiExpiryDateResult> _resolveAiSuggestion({
    required String ocrText,
    required XFile image,
  }) async {
    var aiResult = await _aiExpiryDateClient.suggestDateFromOcrText(ocrText);
    if (aiResult.date != null || !_aiExpiryDateClient.isEnabled) {
      return aiResult;
    }

    final imageBytes = await image.readAsBytes();
    final imageAiResult = await _aiExpiryDateClient.suggestDateFromImageBytes(
      imageBytes,
    );
    if (imageAiResult.date != null ||
        aiResult.status != AiExpiryDateStatus.found) {
      aiResult = imageAiResult;
    }
    return aiResult;
  }

  String _aiDebugLabel(AiExpiryDateStatus status) {
    switch (status) {
      case AiExpiryDateStatus.found:
        return 'AI: used';
      case AiExpiryDateStatus.noDate:
        return 'AI: no date';
      case AiExpiryDateStatus.failed:
        return 'AI: failed';
      case AiExpiryDateStatus.disabled:
        return 'AI: disabled';
      case AiExpiryDateStatus.emptyInput:
        return 'AI: empty OCR';
    }
  }

  String _aiDebugLabelWithSource(AiExpiryDateResult result) {
    if (result.status == AiExpiryDateStatus.found &&
        result.source == AiExpiryDateSource.image) {
      return 'AI: image used';
    }
    if (result.status == AiExpiryDateStatus.found &&
        result.source == AiExpiryDateSource.text) {
      return 'AI: text used';
    }
    return _aiDebugLabel(result.status);
  }

  ExpiryDateAnalysis _mergeWithAiSuggestion(
    ExpiryDateAnalysis local,
    DateTime? aiDate,
  ) {
    if (aiDate == null) {
      return local;
    }

    final normalizedAi = DateTime(aiDate.year, aiDate.month, aiDate.day);
    final candidates = <DateTime>[
      normalizedAi,
      ...local.candidates.where(
        (d) =>
            !(d.year == normalizedAi.year &&
                d.month == normalizedAi.month &&
                d.day == normalizedAi.day),
      ),
    ];

    return ExpiryDateAnalysis(
      ocrText: local.ocrText,
      candidates: candidates,
      suggestedDate: normalizedAi,
    );
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

  Future<_DateSuggestionSheetResult?> _showDateSuggestionSheet(
    ExpiryDateAnalysis analysis, {
    required String title,
    bool allowTryAi = false,
  }) {
    return showModalBottomSheet<_DateSuggestionSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final candidates = analysis.candidates.take(6).toList(growable: false);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Detected text:\n${analysis.ocrText.trim().isEmpty ? '(empty)' : analysis.ocrText.trim()}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (analysis.suggestedDate != null)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _DateSuggestionSheetResult(date: analysis.suggestedDate),
                    ),
                    child: Text(
                      'Use suggested: ${_formatDate(analysis.suggestedDate!)}',
                    ),
                  ),
                const SizedBox(height: 8),
                ...candidates.map(
                  (date) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_formatDate(date)),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_DateSuggestionSheetResult(date: date)),
                  ),
                ),
                if (allowTryAi)
                  OutlinedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _DateSuggestionSheetResult(requestAi: true)),
                    child: const Text('Try AI suggestion'),
                  ),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
      appBar: AppBar(title: Text(widget.isEditMode ? 'Edit Item' : 'Add Item')),
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
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _scanExpirationDate,
                        child: const Text('Scan expiry'),
                      ),
                      OutlinedButton(
                        onPressed: _pickDate,
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.isEditMode ? 'Save Changes' : 'Save Item',
                    ),
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
