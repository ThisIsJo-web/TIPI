import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/grocery_run.dart';
import '../../models/grocery_run_item.dart';
import '../../models/price_item.dart';
import '../../services/api_service.dart';
import '../../services/cache_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/custom_alert.dart';
import '../../widgets/tipi_progress_bar.dart';
import 'active_run_view.dart';

class RunBuilderView extends StatefulWidget {
  final GroceryRun? run; // If null, we are creating a new run

  const RunBuilderView({super.key, this.run});

  @override
  State<RunBuilderView> createState() => _RunBuilderViewState();
}

class _RunBuilderViewState extends State<RunBuilderView> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  
  String _selectedStore = "Tagum Public Market";
  DateTime _plannedDate = DateTime.now();
  TimeOfDay _plannedTime = TimeOfDay.now();
  
  bool _isLoading = false;
  String _searchQuery = "";
  
  // Temporary local list of run items, to allow drafting prior to db sync
  List<GroceryRunItem> _localItems = [];
  String? _existingRunId;
  String _status = 'draft';

  final List<String> _markets = [
    "Tagum Public Market",
    "Panabo Public Market",
    "Other Store / Supermarket"
  ];

  final List<String> _categories = [
    "Cereals",
    "Meat, Fish and Poultry",
    "Vegetables and Fruits",
    "Milk and Dairy",
    "Miscellaneous",
    "Custom"
  ];

  @override
  void initState() {
    super.initState();
    _existingRunId = widget.run?.id;
    _nameController = TextEditingController(text: widget.run?.name ?? "");
    _budgetController = TextEditingController(
      text: widget.run != null ? widget.run!.budget.toStringAsFixed(0) : "1500"
    );
    _status = widget.run?.status ?? 'draft';

    if (widget.run != null) {
      _localItems = List.from(widget.run!.items);
      _plannedDate = widget.run!.createdAt;
      _plannedTime = TimeOfDay.fromDateTime(widget.run!.createdAt);
      
      // Determine store if matching list
      final itemMarkets = widget.run!.items.map((i) => i.market).toSet();
      if (itemMarkets.isNotEmpty) {
        final firstMarket = itemMarkets.first;
        if (_markets.contains(firstMarket)) {
          _selectedStore = firstMarket;
        } else {
          _selectedStore = "Other Store / Supermarket";
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  double get _targetBudget => double.tryParse(_budgetController.text) ?? 0.0;

  double get _estimatedTotal {
    return _localItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: ThemeService.instance.primary,
              brightness: ThemeService.instance.isDarkMode.value ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _plannedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _plannedTime,
    );
    if (picked != null) {
      setState(() {
        _plannedTime = picked;
      });
    }
  }

  // Group items by category for visual hierarchy
  Map<String, List<GroceryRunItem>> get _groupedItems {
    final Map<String, List<GroceryRunItem>> grouped = {};
    for (var cat in _categories) {
      grouped[cat] = [];
    }
    
    for (var item in _localItems) {
      final cat = _categories.contains(item.category) ? item.category : "Custom";
      grouped[cat]!.add(item);
    }

    // Clean up empty category lists
    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  // --- Save Logic ---
  Future<GroceryRun?> _saveRunDetails({String? overrideStatus}) async {
    if (!_formKey.currentState!.validate()) return null;

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final budget = _targetBudget;
    final status = overrideStatus ?? _status;

    GroceryRun? targetRun;

    if (_existingRunId == null) {
      // Create new Run Header record
      targetRun = await ApiService.instance.createRun(name, budget);
      if (targetRun != null) {
        _existingRunId = targetRun.id;
      }
    } else {
      // Update existing Run Header
      targetRun = await ApiService.instance.updateRun(
        _existingRunId!,
        name: name,
        budget: budget,
        status: status,
      );
    }

    if (targetRun == null) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomAlert.show(context, message: "Error saving trip header.", isError: true);
      }
      return null;
    }

    // Sync individual items: Simple diff syncer
    // Fetch currently saved items for this run in database
    final updatedRunsList = await ApiService.instance.fetchRuns();
    final refreshedRun = updatedRunsList.firstWhere(
      (r) => r.id == _existingRunId,
      orElse: () => targetRun!,
    );
    final dbItemsMap = {for (var i in refreshedRun.items) i.id: i};

    // 1. Delete items from db that aren't in local list
    final localIds = _localItems.map((i) => i.id).toSet();
    for (var dbItem in refreshedRun.items) {
      if (!localIds.contains(dbItem.id)) {
        await ApiService.instance.deleteRunItem(_existingRunId!, dbItem.id);
      }
    }

    // 2. Add or update items
    for (var localItem in _localItems) {
      // If item starts with "temp_", it is newly added locally. Create in db!
      if (localItem.id.startsWith("temp_")) {
        await ApiService.instance.addRunItem(
          _existingRunId!,
          commodity: localItem.commodity,
          price: localItem.price,
          quantity: localItem.quantity,
          unit: localItem.unit,
          category: localItem.category,
          market: localItem.market,
        );
      } else {
        // Exists in DB. Compare and update if quantity or price changed
        final dbItem = dbItemsMap[localItem.id];
        if (dbItem != null && (dbItem.quantity != localItem.quantity || dbItem.price != localItem.price)) {
          await ApiService.instance.updateRunItem(
            _existingRunId!,
            localItem.id,
            quantity: localItem.quantity,
            price: localItem.price,
          );
        }
      }
    }

    // Load final synchronized run record
    final finalRuns = await ApiService.instance.fetchRuns();
    final savedRun = finalRuns.firstWhere(
      (r) => r.id == _existingRunId,
      orElse: () => targetRun!,
    );

    setState(() {
      _isLoading = false;
    });

    return savedRun;
  }

  // Add Item to Local List
  void _addLocalItem({
    required String commodity,
    required double price,
    required double quantity,
    required String unit,
    required String category,
    required String market,
  }) {
    final tempItem = GroceryRunItem(
      id: "temp_${DateTime.now().millisecondsSinceEpoch}",
      runId: _existingRunId ?? "",
      commodity: commodity,
      price: price,
      quantity: quantity,
      unit: unit,
      category: category,
      market: market,
      checked: false,
    );

    setState(() {
      _localItems.add(tempItem);
    });
  }

  // Edit Local Item inline
  void _editLocalItem(GroceryRunItem item, double price, double quantity) {
    setState(() {
      final index = _localItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _localItems[index] = GroceryRunItem(
          id: item.id,
          runId: item.runId,
          commodity: item.commodity,
          price: price,
          quantity: quantity,
          unit: item.unit,
          category: item.category,
          market: item.market,
          checked: item.checked,
        );
      }
    });
  }

  // Remove Local Item
  void _removeLocalItem(String id) {
    setState(() {
      _localItems.removeWhere((item) => item.id == id);
    });
  }

  // --- Modal Search Sheet ---
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
              Future.wait([
                ApiService.instance.fetchCustomCommodities(),
                CacheService.instance.syncDataset(),
              ]).then((results) {
                if (sheetContext.mounted) {
                  setSheetState(() {
                    customList = results[0] as List<PriceItem>;
                  });
                }
              });
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            List<PriceItem> listToShow = [
              ...CacheService.instance.cachedPrices,
              ...customList
            ];

            // Filter by search query if user typed something
            if (_searchQuery.isNotEmpty) {
              listToShow = listToShow.where((item) =>
                item.commodity.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.market.toLowerCase().contains(_searchQuery.toLowerCase())
              ).toList();
            }

            // Uniqueness parsing by commodity name
            final uniqueMap = <String, PriceItem>{};
            for (var item in listToShow) {
              final key = item.commodity.toLowerCase().trim();
              if (!uniqueMap.containsKey(key)) {
                uniqueMap[key] = item;
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
                        "Search Commodities",
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
                      hintText: "Search regular rice, chicken, sugar...",
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
                  
                  // Custom item adder button
                  ListTile(
                    leading: Icon(Icons.add_circle_outline, color: ThemeService.instance.primary),
                    title: Text(
                      _searchQuery.isEmpty ? "Add custom commodity..." : 'Add custom: "$_searchQuery"',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ThemeService.instance.primary,
                      ),
                    ),
                    subtitle: const Text("Plan an item not in database reference"),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showAddCustomItemDialog(_searchQuery);
                    },
                  ),
                  const Divider(),
                  
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                    ),
                    child: uniqueList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text("No items match filters. Try typing a custom name!"),
                            ),
                          )
                        : ListView.separated(
                            itemCount: uniqueList.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (itemCtx, index) {
                              final priceItem = uniqueList[index];
                              return ListTile(
                                title: Text(
                                  priceItem.commodity,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  "₱${priceItem.price.toStringAsFixed(2)} / ${priceItem.unit} at ${priceItem.market.isEmpty ? 'General Reference' : priceItem.market}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Icon(
                                  Icons.add_shopping_cart,
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

  // Configure reference price item details
  void _showConfigureItemDialog(PriceItem priceItem) {
    final qtyController = TextEditingController(text: "1.0");
    final priceController = TextEditingController(text: priceItem.price.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ThemeService.instance.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Configure ${priceItem.commodity}",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Market: ${priceItem.market.isEmpty ? _selectedStore : priceItem.market}",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: "Estimated Unit Price (PHP)",
                  suffixText: "per ${priceItem.unit}",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: qtyController,
                decoration: InputDecoration(
                  labelText: "Planned Quantity",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final price = double.tryParse(priceController.text) ?? priceItem.price;
                final qty = double.tryParse(qtyController.text) ?? 1.0;
                
                _addLocalItem(
                  commodity: priceItem.commodity,
                  price: price,
                  quantity: qty,
                  unit: priceItem.unit,
                  category: priceItem.category.isEmpty ? "Miscellaneous" : priceItem.category,
                  market: priceItem.market.isEmpty ? _selectedStore : priceItem.market,
                );
                
                Navigator.of(ctx).pop();
              },
              child: const Text("CONFIRM"),
            ),
          ],
        );
      },
    );
  }

  // Configure custom item parameters
  void _showAddCustomItemDialog(String initialName) {
    final nameController = TextEditingController(text: initialName);
    final priceController = TextEditingController(text: "0.0");
    final qtyController = TextEditingController(text: "1.0");
    final unitController = TextEditingController(text: "pcs");
    String selectedCategory = "Custom";

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: ThemeService.instance.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      decoration: const InputDecoration(labelText: "Item Name"),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: "Category"),
                      items: _categories.map((c) {
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
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: priceController,
                            decoration: const InputDecoration(labelText: "Est. Price (PHP)"),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      decoration: const InputDecoration(labelText: "Quantity"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    final price = double.tryParse(priceController.text) ?? 0.0;
                    final qty = double.tryParse(qtyController.text) ?? 1.0;
                    final unit = unitController.text.trim().isEmpty ? "pcs" : unitController.text.trim();

                    _addLocalItem(
                      commodity: name,
                      price: price,
                      quantity: qty,
                      unit: unit,
                      category: selectedCategory,
                      market: _selectedStore,
                    );

                    Navigator.of(ctx).pop();
                  },
                  child: const Text("ADD TO PLAN"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Edit dialog for existing items in local planning checklist
  void _showEditLocalItemDialog(GroceryRunItem item) {
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(1));
    final priceController = TextEditingController(text: item.price.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ThemeService.instance.surface,
          title: Text(
            "Adjust ${item.commodity}",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: "Est. Price per ${item.unit} (PHP)",
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: "Quantity"),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
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
              onPressed: () {
                final price = double.tryParse(priceController.text) ?? item.price;
                final qty = double.tryParse(qtyController.text) ?? item.quantity;
                _editLocalItem(item, price, qty);
                Navigator.of(ctx).pop();
              },
              child: const Text("SAVE"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    final primaryColor = ThemeService.instance.primary;
    final isExceeded = _estimatedTotal > _targetBudget;

    return Scaffold(
      backgroundColor: ThemeService.instance.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.run == null ? "PLAN GROCERY RUN" : "EDIT PLAN",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: () async {
                final saved = await _saveRunDetails();
                if (saved != null && mounted) {
                  CustomAlert.show(context, message: "Plan saved successfully!", isSuccess: true);
                  Navigator.of(context).pop(true);
                }
              },
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: const Text(
                "SAVE PLAN",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 120.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Trip Metadata Card ---
                    Card(
                      color: ThemeService.instance.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Trip Metadata",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : Colors.black54,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: "Trip Name (e.g. Saturday Stocking)",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.edit_note),
                              ),
                              validator: (val) => val == null || val.isEmpty ? "Name is required" : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _budgetController,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: "Budget Ceiling (PHP)",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      prefixIcon: const Icon(Icons.payments_outlined),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return "Required";
                                      if (double.tryParse(val) == null) return "Invalid";
                                      return null;
                                    },
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedStore,
                                    decoration: InputDecoration(
                                      labelText: "Store Market",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                    items: _markets.map((m) {
                                      return DropdownMenuItem(
                                        value: m,
                                        child: Text(
                                          m.split(' ').first,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedStore = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Planned date pickers
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectDate,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today_outlined, size: 16, color: primaryColor),
                                          const SizedBox(width: 8),
                                          Text(
                                            "${_plannedDate.month}/${_plannedDate.day}/${_plannedDate.year}",
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: _selectTime,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time, size: 16, color: primaryColor),
                                          const SizedBox(width: 8),
                                          Text(
                                            _plannedTime.format(context),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Shopping List Header ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Planned Commodities",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddCommoditySheet,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("ADD ITEM", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- Planning list grouped by category ---
                    if (_localItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.playlist_add, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                "No items planned yet. Tap 'ADD ITEM' to select from WFP prices reference.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._groupedItems.entries.map((entry) {
                        final category = entry.key;
                        final items = entry.value;
                        final categoryTotal = items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    category.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    "Subtotal: ₱${categoryTotal.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final item = items[idx];
                                return Card(
                                  margin: EdgeInsets.zero,
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      item.commodity,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      "₱${item.price.toStringAsFixed(2)} / ${item.unit} at ${item.market.split(' ').first}",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "${item.quantity.toStringAsFixed(1)} ${item.unit}",
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          onPressed: () => _showEditLocalItemDialog(item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                          onPressed: () => _removeLocalItem(item.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ).animate(delay: (idx * 30).ms).fade(duration: 250.ms).slideY(begin: 0.08, end: 0.0, duration: 250.ms, curve: Curves.easeOutCubic);
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Est budget progress bar
              TipiProgressBar(
                current: _estimatedTotal,
                limit: _targetBudget,
                height: 8,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text(
                        "SAVE DRAFT",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final saved = await _saveRunDetails();
                              if (saved != null && mounted) {
                                CustomAlert.show(context, message: "Draft saved successfully!", isSuccess: true);
                                Navigator.of(context).pop(true);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D5C2C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout),
                      label: const Text(
                        "START SHOPPING",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              // Save as active and open ActiveRunView
                              final saved = await _saveRunDetails(overrideStatus: 'active');
                              if (saved != null && mounted) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => ActiveRunView(run: saved),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
