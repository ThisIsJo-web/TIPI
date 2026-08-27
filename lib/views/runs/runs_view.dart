import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../services/theme_service.dart';
import '../../services/translation_service.dart';
import '../../models/grocery_run.dart';
import '../../models/grocery_run_item.dart';
import '../../models/price_item.dart';
import '../../widgets/custom_alert.dart';

class RunsView extends StatefulWidget {
  final GroceryRun run;

  const RunsView({super.key, required this.run});

  @override
  State<RunsView> createState() => _RunsViewState();
}

class _RunsViewState extends State<RunsView> {
  late GroceryRun _currentRun;
  bool _isLoading = false;
  List<PriceItem> _filteredPrices = [];
  String _searchQuery = "";
  final GlobalKey _receiptKey = GlobalKey();

  // The virtual markets for Davao del Norte
  final List<String> _markets = ["Panabo Public Market", "Tagum Public Market"];

  @override
  void initState() {
    super.initState();
    _currentRun = widget.run;
    _filteredPrices = CacheService.instance.cachedPrices;
  }

  Future<void> _refreshRun() async {
    final runs = await ApiService.instance.fetchRuns();
    final updated = runs.firstWhere((r) => r.id == _currentRun.id, orElse: () => _currentRun);
    setState(() {
      _currentRun = updated;
    });
  }

  Future<void> _toggleItemChecked(GroceryRunItem item) async {
    final updated = await ApiService.instance.updateRunItem(
      _currentRun.id,
      item.id,
      checked: !item.checked,
    );
    if (updated != null) {
      _refreshRun();
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final success = await ApiService.instance.deleteRunItem(_currentRun.id, itemId);
    if (success) {
      _refreshRun();
    }
  }

  Future<void> _updateItemQuantity(GroceryRunItem item, double change) async {
    final newQty = (item.quantity + change).clamp(0.1, 99.0);
    final updated = await ApiService.instance.updateRunItem(
      _currentRun.id,
      item.id,
      quantity: newQty,
    );
    if (updated != null) {
      _refreshRun();
    }
  }

  void _showAddCommoditySheet() {
    bool didFetchCustom = false;
    List<PriceItem> customList = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeService.instance.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            if (!didFetchCustom) {
              didFetchCustom = true;
              ApiService.instance.fetchCustomCommodities().then((fetched) {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    customList = fetched;
                  });
                }
              });
            }

            final isDark = ThemeService.instance.isDarkMode.value;

            // Search filtering logic: Merge local cached WFP items and shared shopper items
            List<PriceItem> listToShow = [
              ...CacheService.instance.cachedPrices,
              ...customList
            ];

            if (_searchQuery.isNotEmpty) {
              listToShow = listToShow.where((item) =>
                item.commodity.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.category.toLowerCase().contains(_searchQuery.toLowerCase())
              ).toList();
            }

            // Get only the most recent record per commodity to show unique items
            final uniqueMap = <String, PriceItem>{};
            for (var item in listToShow) {
              if (!uniqueMap.containsKey(item.commodity.toLowerCase().trim())) {
                uniqueMap[item.commodity.toLowerCase().trim()] = item;
              }
            }
            final uniqueList = uniqueMap.values.toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Add Commodity to Run",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search commodities (e.g. Regular Rice, Pork)...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (val) {
                      setSheetState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Icon(Icons.add_circle_outline, color: ThemeService.instance.primary),
                    title: Text(
                      _searchQuery.isEmpty ? "Add custom item..." : 'Add custom item: "$_searchQuery"',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ThemeService.instance.primary,
                      ),
                    ),
                    subtitle: const Text("Create a commodity not found in the WFP database"),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showAddCustomItemDialog(_searchQuery);
                    },
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.35,
                    ),
                    child: uniqueList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text("No commodities matched search query."),
                            ),
                          )
                        : ListView.separated(
                            itemCount: uniqueList.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (itemCtx, index) {
                              final priceItem = uniqueList[index];
                              final isCustom = priceItem.date.isEmpty;
                              return ListTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        priceItem.commodity,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isCustom)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "👥 Shopper Shared",
                                          style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  isCustom
                                      ? "Shopper Price: ₱${priceItem.price.toStringAsFixed(2)} / ${priceItem.unit} (At ${priceItem.market})"
                                      : "WFP Reference: ₱${priceItem.price.toStringAsFixed(2)} / ${priceItem.unit} (${priceItem.category})",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Icon(
                                  Icons.add_circle_outline,
                                  color: ThemeService.instance.primary,
                                ),
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _showConfigureItemDialog(priceItem);
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomItemDialog(String initialName) {
    String selectedMarket = _markets[0];
    String selectedCategory = "Custom";
    final nameController = TextEditingController(text: initialName);
    final priceController = TextEditingController(text: "0.0");
    final qtyController = TextEditingController(text: "1.0");
    final unitController = TextEditingController(text: "kg");
    
    final List<String> categories = [
      "Custom",
      "Cereals",
      "Meat, Fish and Poultry",
      "Vegetables and Fruits",
      "Milk and Dairy",
      "Miscellaneous"
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = ThemeService.instance.isDarkMode.value;
            return AlertDialog(
              backgroundColor: ThemeService.instance.surface,
              title: Text(
                "Add Custom Item",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Commodity Name"),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: "Category"),
                      items: categories.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedCategory = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedMarket,
                      decoration: const InputDecoration(labelText: "Target Market"),
                      items: _markets.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedMarket = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: priceController,
                            decoration: const InputDecoration(labelText: "Price (PHP)"),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: unitController,
                            decoration: const InputDecoration(labelText: "Unit"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: "Quantity Needed"),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeService.instance.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    Navigator.of(ctx).pop();
                    final customPrice = double.tryParse(priceController.text) ?? 0.0;
                    final quantity = double.tryParse(qtyController.text) ?? 1.0;
                    final unit = unitController.text.trim().isEmpty ? "kg" : unitController.text.trim();

                    final added = await ApiService.instance.addRunItem(
                      _currentRun.id,
                      commodity: name,
                      price: customPrice,
                      quantity: quantity,
                      unit: unit,
                      category: selectedCategory,
                      market: selectedMarket,
                    );

                    if (added != null) {
                      _refreshRun();
                    }
                  },
                  child: const Text("ADD TO LIST"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showConfigureItemDialog(PriceItem priceItem) {
    String selectedMarket = _markets[0];
    final qtyController = TextEditingController(text: "1.0");
    final priceController = TextEditingController(text: priceItem.price.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = ThemeService.instance.isDarkMode.value;
            return AlertDialog(
              backgroundColor: ThemeService.instance.surface,
              title: Text(
                "Add ${priceItem.commodity}",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMarket,
                      decoration: const InputDecoration(labelText: "Choose Target Market"),
                      items: _markets.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedMarket = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: "Custom Price per ${priceItem.unit} (PHP)",
                        suffixText: "Ref: ₱${priceItem.price.toStringAsFixed(2)}",
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: "Quantity Needed"),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("CANCEL"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeService.instance.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final customPrice = double.tryParse(priceController.text) ?? priceItem.price;
                    final quantity = double.tryParse(qtyController.text) ?? 1.0;

                    final added = await ApiService.instance.addRunItem(
                      _currentRun.id,
                      commodity: priceItem.commodity,
                      price: customPrice,
                      quantity: quantity,
                      unit: priceItem.unit,
                      category: priceItem.category,
                      market: selectedMarket,
                    );

                    if (added != null) {
                      _refreshRun();
                    }
                  },
                  child: const Text("ADD TO LIST"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _finishRun() async {
    // 1. Set status to completed (this automatically increments user stats on the backend!)
    await _updateRunStatus('completed');
    
    if (!mounted) return;

    final savings = _currentRun.budget - _currentRun.spent;
    final displaySavings = savings < 0 ? 0.0 : savings;

    // 2. Show completion dialog and prompt for receipt
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = ThemeService.instance.isDarkMode.value;
        return AlertDialog(
          backgroundColor: ThemeService.instance.surface,
          title: Text(
            TranslationService.instance.t('finish_success'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "${TranslationService.instance.t('savings_msg')}: ₱${displaySavings.toStringAsFixed(2)}!",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
              ),
              const SizedBox(height: 12),
              Text(
                TranslationService.instance.t('generate_receipt_prompt'),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                CustomAlert.show(context, message: TranslationService.instance.t('finish_success'), isSuccess: true);
              },
              child: Text(TranslationService.instance.t('no')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.instance.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _showVisualReceiptDialog();
              },
              child: Text(TranslationService.instance.t('yes')),
            ),
          ],
        );
      },
    );
  }

  void _showVisualReceiptDialog() {
    final savings = _currentRun.budget - _currentRun.spent;
    final displaySavings = savings < 0 ? 0.0 : savings;
    Uint8List? generatedImageBytes;
    String? savedFilePath;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = ThemeService.instance.isDarkMode.value;
            
            // Define receipt visual design card
            Widget receiptCard = Container(
              width: 300,
              padding: const EdgeInsets.all(20),
              color: Colors.white, // Authentic receipt white paper
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      "🧾 TIPI E-RECEIPT",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "Matipid Grocery Shopping",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "Davao del Norte, PH",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "DATE: ${DateTime.now().toString().split(' ').first}",
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "RUN: ${_currentRun.name.toUpperCase()}",
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                  const Divider(color: Colors.black54, thickness: 1, height: 16),
                  
                  // Items Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("ITEM", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                      Text("TOTAL", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                    ],
                  ),
                  const Divider(color: Colors.black38, thickness: 0.5, height: 8),
                  
                  // Items List
                  ..._currentRun.items.map((item) {
                    final itemTotal = item.price * item.quantity;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "${item.commodity} (${item.quantity.toStringAsFixed(1)} ${item.unit})",
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 10,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "₱${itemTotal.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  const Divider(color: Colors.black54, thickness: 1, height: 16),
                  
                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("BUDGET LIMIT:", style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87)),
                      Text("₱${_currentRun.budget.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("ACTUAL SPENT:", style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87)),
                      Text("₱${_currentRun.spent.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "TOTAL SAVED:",
                        style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                      ),
                      Text(
                        "₱${displaySavings.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(color: Colors.black54, thickness: 1, height: 20),
                  
                  // Barcode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(24, (index) => Container(
                      width: (index % 3 == 0) ? 3.0 : (index % 2 == 0) ? 1.5 : 2.0,
                      height: 36,
                      color: Colors.black87,
                      margin: const EdgeInsets.symmetric(horizontal: 0.8),
                    )),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "#TIPI-${_currentRun.id.substring(0, 8).toUpperCase()}",
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 9,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            );

            return AlertDialog(
              backgroundColor: ThemeService.instance.surface,
              contentPadding: const EdgeInsets.all(12),
              title: Text(
                generatedImageBytes == null ? "TIPI E-Receipt Preview" : "Generated E-Receipt Image",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (generatedImageBytes == null)
                      RepaintBoundary(
                        key: _receiptKey,
                        child: receiptCard,
                      )
                    else ...[
                      // Show the generated image!
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Image.memory(generatedImageBytes!),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "🎉 E-Receipt image generated successfully!\n\nYou can now save it directly to your phone's photo gallery, or take a screenshot!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(generatedImageBytes == null ? "CLOSE" : "DONE"),
                ),
                if (generatedImageBytes != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        final result = await ImageGallerySaver.saveImage(
                          generatedImageBytes!,
                          name: "tipi_receipt_${_currentRun.id.substring(0, 8)}",
                        );
                        final success = result != null && result['isSuccess'] == true;
                        
                        if (mounted) {
                          if (success) {
                            CustomAlert.show(
                              context,
                              message: "Receipt Image saved to Gallery successfully!",
                              isSuccess: true,
                            );
                          } else {
                            CustomAlert.show(
                              context,
                              message: "Failed to save receipt image to Gallery.",
                              isError: true,
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint("Error saving receipt to gallery: $e");
                        if (mounted) {
                          CustomAlert.show(
                            context,
                            message: "Failed to save receipt image to Gallery: $e",
                            isError: true,
                          );
                        }
                      }
                    },
                    child: const Text("SAVE TO GALLERY"),
                  ),
                if (generatedImageBytes == null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeService.instance.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      // Trigger image capture
                      try {
                        RenderRepaintBoundary boundary = _receiptKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                        if (byteData != null) {
                          final pngBytes = byteData.buffer.asUint8List();
                          
                          // Write file
                          final tempDir = await getTemporaryDirectory();
                          final file = File('${tempDir.path}/tipi_receipt_${_currentRun.id.substring(0, 8)}.png');
                          await file.writeAsBytes(pngBytes);
                          
                          setDialogState(() {
                            generatedImageBytes = pngBytes;
                            savedFilePath = file.path;
                          });
                        }
                      } catch (e) {
                        debugPrint("Error generating receipt image: $e");
                      }
                    },
                    child: const Text("GENERATE PICTURE"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateRunStatus(String status) async {
    final updated = await ApiService.instance.updateRun(_currentRun.id, status: status);
    if (updated != null) {
      setState(() {
        _currentRun = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    double progress = _currentRun.budget > 0 
        ? (_currentRun.spent / _currentRun.budget).clamp(0.0, 1.0) 
        : 0.0;
    bool isOverBudget = _currentRun.spent > _currentRun.budget;

    return Scaffold(
      backgroundColor: ThemeService.instance.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _currentRun.name.toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          // Run status selector dropdown
          DropdownButton<String>(
            value: _currentRun.status,
            dropdownColor: ThemeService.instance.surface,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: ThemeService.instance.primary),
            items: const [
              DropdownMenuItem(value: 'active', child: Text("Active", style: TextStyle(fontSize: 14))),
              DropdownMenuItem(value: 'draft', child: Text("Draft", style: TextStyle(fontSize: 14))),
              DropdownMenuItem(value: 'completed', child: Text("Done", style: TextStyle(fontSize: 14))),
            ],
            onChanged: (val) {
              if (val != null) {
                _updateRunStatus(val);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ThemeService.instance.surface,
                  title: const Text("Delete Run?"),
                  content: const Text("Are you sure you want to permanently delete this grocery run?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("CANCEL")),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text("DELETE", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                await ApiService.instance.deleteRun(_currentRun.id);
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Budget Bar Header Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: ThemeService.instance.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Run Progress", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(
                      "₱${_currentRun.spent.toStringAsFixed(2)} / ₱${_currentRun.budget.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isOverBudget ? Colors.red : ThemeService.instance.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    color: isOverBudget ? Colors.red : ThemeService.instance.primary,
                  ),
                ),
              ],
            ),
          ),

          // Items Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              "Shopping List (${_currentRun.items.length} items)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),

          // Items list
          Expanded(
            child: _currentRun.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "Your grocery run shopping list is empty.",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _currentRun.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = _currentRun.items[idx];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          _deleteItem(item.id);
                        },
                        child: Card(
                          color: ThemeService.instance.surface,
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  activeColor: ThemeService.instance.primary,
                                  value: item.checked,
                                  onChanged: (_) => _toggleItemChecked(item),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.commodity,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          decoration: item.checked ? TextDecoration.lineThrough : null,
                                          color: isDark
                                              ? (item.checked ? Colors.white38 : Colors.white)
                                              : (item.checked ? Colors.black38 : Colors.black87),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${item.market}  •  ₱${item.price.toStringAsFixed(2)} / ${item.unit}",
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity selector
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: () => _updateItemQuantity(item, -0.5),
                                    ),
                                    Text(
                                      item.quantity.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () => _updateItemQuantity(item, 0.5),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _currentRun.status == 'completed'
          ? null
          : FloatingActionButton.extended(
              backgroundColor: ThemeService.instance.primary,
              onPressed: _showAddCommoditySheet,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(TranslationService.instance.t('add_commodity').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
      bottomNavigationBar: _currentRun.status == 'active'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6B39),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    TranslationService.instance.t('finish_run'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _finishRun,
                ),
              ),
            )
          : null,
    );
  }
}
