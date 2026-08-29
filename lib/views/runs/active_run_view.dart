import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/grocery_run.dart';
import '../../models/grocery_run_item.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/active_spend_sticky_header.dart';
import '../../widgets/commodity_checklist_tile.dart';
import '../../widgets/custom_alert.dart';
import '../../widgets/motion/shake_widget.dart';

class ActiveRunView extends StatefulWidget {
  final GroceryRun run;

  const ActiveRunView({super.key, required this.run});

  @override
  State<ActiveRunView> createState() => _ActiveRunViewState();
}

class _ActiveRunViewState extends State<ActiveRunView> {
  late GroceryRun _currentRun;
  bool _isLoading = false;
  final GlobalKey _receiptKey = GlobalKey();
  
  // Track items currently playing slide collapse animations
  final Set<String> _transitioningIds = {};

  @override
  void initState() {
    super.initState();
    _currentRun = widget.run;
  }

  Future<void> _refreshRun() async {
    final oldSpent = _currentRun.spent;
    final oldBudget = _currentRun.budget;

    final runs = await ApiService.instance.fetchRuns();
    final updated = runs.firstWhere((r) => r.id == _currentRun.id, orElse: () => _currentRun);
    
    // Play physical alarm feedbacks if exceeding planned budget ceiling
    final wasUnder = oldSpent <= oldBudget;
    final isNowOver = updated.spent > updated.budget;

    if (isNowOver && wasUnder) {
      HapticFeedback.mediumImpact();
      ToastService.instance.showToast(
        context,
        title: "Over Budget Ceiling!",
        message: "You exceeded your limit by ₱${(updated.spent - updated.budget).toStringAsFixed(2)}!",
        isError: true,
      );
    } else if (updated.spent > oldSpent && !isNowOver) {
      // Small selection click on normal shopping increments
      HapticFeedback.selectionClick();
    }

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
      await _refreshRun();
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final success = await ApiService.instance.deleteRunItem(_currentRun.id, itemId);
    if (success) {
      _refreshRun();
    }
  }

  void _showAdjustPriceDialog(GroceryRunItem item) {
    final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ThemeService.instance.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "In-Store Price Check",
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
                item.commodity,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: "Actual Store Price per ${item.unit} (PHP)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: qtyController,
                decoration: InputDecoration(
                  labelText: "Actual Quantity Purchased",
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
              onPressed: () async {
                Navigator.of(ctx).pop();
                final actualPrice = double.tryParse(priceController.text) ?? item.price;
                final actualQty = double.tryParse(qtyController.text) ?? item.quantity;

                final updated = await ApiService.instance.updateRunItem(
                  _currentRun.id,
                  item.id,
                  price: actualPrice,
                  quantity: actualQty,
                );
                if (updated != null) {
                  _refreshRun();
                }
              },
              child: const Text("SAVE CHANGES"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishErrand() async {
    setState(() {
      _isLoading = true;
    });

    final completedRun = await ApiService.instance.updateRun(_currentRun.id, status: 'completed');
    if (completedRun == null) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CustomAlert.show(context, message: "Error updating status.", isError: true);
      }
      return;
    }

    _currentRun = completedRun;

    final savings = _currentRun.budget - _currentRun.spent;
    final displaySavings = savings < 0 ? 0.0 : savings;
    
    final currentUser = ApiService.instance.currentUser;
    if (currentUser != null) {
      final updatedRunsCount = (currentUser.runsCompleted) + 1;
      final updatedSavedAmount = (currentUser.totalSaved) + displaySavings;

      await ApiService.instance.updateProfile(
        runsCompleted: updatedRunsCount,
        totalSaved: updatedSavedAmount,
      );
    }

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: ThemeService.instance.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Grocery Errand Finished!",
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
                "Savings Delta: ₱${displaySavings.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF0D5C2C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                savings >= 0
                    ? "Great job! You stayed under your planned budget ceiling."
                    : "You exceeded your planned budget ceiling by ₱${savings.abs().toStringAsFixed(2)}.",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                "Would you like to generate and export a visual receipt picture to share with others or keep for reference?",
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text("NO, CLOSE"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.instance.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _showVisualReceiptDialog();
              },
              child: const Text("GENERATE RECEIPT"),
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            Widget receiptCard = Container(
              width: 300,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      "🧾 TIPI SHOPPING SUMMARY",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "Smart grocery runs budgeter",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.black54, thickness: 1, height: 16),
                  Text(
                    "DATE: ${DateTime.now().toString().split(' ').first}",
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87),
                  ),
                  Text(
                    "RUN: ${_currentRun.name.toUpperCase()}",
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87),
                  ),
                  const Divider(color: Colors.black38, thickness: 0.5, height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("ITEM / QTY", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                      Text("SUBTOTAL", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                    ],
                  ),
                  const Divider(color: Colors.black38, thickness: 0.5, height: 8),
                  
                  ..._currentRun.items.map((item) {
                    final itemTotal = item.price * item.quantity;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${item.commodity} (${item.quantity.toStringAsFixed(1)} ${item.unit})",
                              style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "₱${itemTotal.toStringAsFixed(2)}",
                            style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: Colors.black87),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  const Divider(color: Colors.black54, thickness: 1, height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("BUDGET CEILING:", style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.black87)),
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
                        "TOTAL SAVINGS:",
                        style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                      ),
                      Text(
                        "₱${displaySavings.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF0D5C2C),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.black54, thickness: 1, height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(24, (index) => Container(
                      width: (index % 3 == 0) ? 3.0 : (index % 2 == 0) ? 1.5 : 2.0,
                      height: 30,
                      color: Colors.black87,
                      margin: const EdgeInsets.symmetric(horizontal: 0.8),
                    )),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "#TIPI-${_currentRun.id.substring(0, 8).toUpperCase()}",
                      style: const TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            );

            return AlertDialog(
              backgroundColor: ThemeService.instance.surface,
              contentPadding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                generatedImageBytes == null ? "E-Receipt Summary" : "Generated E-Receipt",
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
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                        child: Image.memory(generatedImageBytes!),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Image generated successfully! Tap below to save it to your phone's photo library.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    Navigator.of(context).pop(true);
                  },
                  child: Text(generatedImageBytes == null ? "CANCEL" : "DONE"),
                ),
                if (generatedImageBytes == null)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        RenderRepaintBoundary boundary = _receiptKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                        if (byteData != null) {
                          final pngBytes = byteData.buffer.asUint8List();
                          setDialogState(() {
                            generatedImageBytes = pngBytes;
                          });
                        }
                      } catch (e) {
                        debugPrint("Error creating receipt: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeService.instance.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("GENERATE FILE"),
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await Gal.putImageBytes(generatedImageBytes!);
                        if (mounted) {
                          CustomAlert.show(context, message: "Saved to photos successfully!", isSuccess: true);
                          Navigator.of(dialogCtx).pop();
                          Navigator.of(context).pop(true);
                        }
                      } catch (e) {
                        debugPrint("Error saving to gallery: $e");
                        if (mounted) {
                          CustomAlert.show(context, message: "Failed to save: $e", isError: true);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("SAVE TO PHOTOS"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    final primaryColor = ThemeService.instance.primary;

    final pendingItems = _currentRun.items.where((i) => !i.checked).toList();
    final completedItems = _currentRun.items.where((i) => i.checked).toList();

    final Map<String, List<GroceryRunItem>> groupedPending = {};
    for (var item in pendingItems) {
      final cat = item.category.isEmpty ? "Miscellaneous" : item.category;
      groupedPending.putIfAbsent(cat, () => []).add(item);
    }

    final isOverBudget = _currentRun.spent > _currentRun.budget;

    return Scaffold(
      backgroundColor: ThemeService.instance.background,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "ACTIVE ERRAND: ${_currentRun.name.toUpperCase()}",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Real-time sticky header ticker wrapped in ShakeWidget
                ShakeWidget(
                  trigger: isOverBudget && _currentRun.spent != 0,
                  child: ActiveSpendStickyHeader(
                    budget: _currentRun.budget,
                    spent: _currentRun.spent,
                    totalItems: _currentRun.items.length,
                    checkedItems: completedItems.length,
                  ),
                ),

                Expanded(
                  child: _currentRun.items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text("No items planned for this run."),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          children: [
                            if (pendingItems.isNotEmpty) ...[
                              ...groupedPending.entries.map((entry) {
                                final category = entry.key;
                                final items = entry.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                                      child: Text(
                                        category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: primaryColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: items.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, idx) {
                                        final item = items[idx];
                                        final isTransitioning = _transitioningIds.contains(item.id);

                                        return AnimatedSize(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOutCubic,
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 250),
                                            opacity: isTransitioning ? 0.0 : 1.0,
                                            child: isTransitioning
                                                ? const SizedBox(height: 0, width: double.infinity)
                                                : CommodityChecklistTile(
                                                    item: item,
                                                    onChecked: (_) async {
                                                      setState(() {
                                                        _transitioningIds.add(item.id);
                                                      });
                                                      await Future.delayed(const Duration(milliseconds: 300));
                                                      await _toggleItemChecked(item);
                                                      if (mounted) {
                                                        setState(() {
                                                          _transitioningIds.remove(item.id);
                                                        });
                                                      }
                                                    },
                                                    onTapEdit: () => _showAdjustPriceDialog(item),
                                                    onDelete: () => _deleteItem(item.id),
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              }).toList(),
                              const SizedBox(height: 24),
                            ],

                            if (completedItems.isNotEmpty) ...[
                              Card(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                  ),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 18,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Completed Items (${completedItems.length})",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    childrenPadding: const EdgeInsets.all(12),
                                    children: [
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: completedItems.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                                        itemBuilder: (context, idx) {
                                          final item = completedItems[idx];
                                          final isTransitioning = _transitioningIds.contains(item.id);

                                          return AnimatedSize(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOutCubic,
                                            child: AnimatedOpacity(
                                              duration: const Duration(milliseconds: 250),
                                              opacity: isTransitioning ? 0.0 : 1.0,
                                              child: isTransitioning
                                                  ? const SizedBox(height: 0, width: double.infinity)
                                                  : CommodityChecklistTile(
                                                      item: item,
                                                      onChecked: (_) async {
                                                        setState(() {
                                                          _transitioningIds.add(item.id);
                                                        });
                                                        await Future.delayed(const Duration(milliseconds: 300));
                                                        await _toggleItemChecked(item);
                                                        if (mounted) {
                                                          setState(() {
                                                            _transitioningIds.remove(item.id);
                                                          });
                                                        }
                                                      },
                                                      onTapEdit: () => _showAdjustPriceDialog(item),
                                                      onDelete: () => _deleteItem(item.id),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                "COMPLETE ERRAND",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: _isLoading ? null : _finishErrand,
            ),
          ),
        ),
      ),
    );
  }
}
