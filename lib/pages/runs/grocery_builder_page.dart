import 'package:flutter/material.dart';
import '../../services/local_db_service.dart';
import '../../services/grocery_run_service.dart';
import '../../widgets/staggered_fade_slide.dart';
import '../../services/theme_service.dart';

class GroceryBuilderPage extends StatefulWidget {
  final Map<String, dynamic>? runData;
  final String? userId;
  final String? detectedCity;
  final String? detectedProvince;

  const GroceryBuilderPage({
    super.key,
    this.runData,
    this.userId,
    this.detectedCity,
    this.detectedProvince,
  });

  @override
  State<GroceryBuilderPage> createState() => _GroceryBuilderPageState();
}

class _GroceryBuilderPageState extends State<GroceryBuilderPage> {
  final _dbService = LocalDbService.instance;
  final _runService = GroceryRunService.instance;

  late String _runId;
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _draftItems = [];
  bool _isSearching = false;
  bool _isLoadingRun = true;
  String _status = 'draft';
  String? _selectedCategory;
  int _selectedTabIndex = 0; // 0: Explore Prices, 1: My List
  String? _activeCategoryFilter = 'All'; // Filter inside shopping mode
  final List<String> _categories = ['Rice', 'Eggs', 'Meat', 'Vegetables'];

  @override
  void initState() {
    super.initState();
    final data = widget.runData ?? {};
    _runId = data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    _nameController = TextEditingController(text: data['name'] ?? 'Palengke Run');
    _budgetController = TextEditingController(text: (data['budget'] ?? 2000).toString());
    _status = data['status'] ?? 'draft';

    _refreshRunFromDb().then((_) {
      _loadLocationPrices();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _parsePrice(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  double _parseQty(dynamic val) {
    if (val == null) return 1.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 1.0;
    return 1.0;
  }

  // SSOT: Always fetch directly from the database query state
  Future<void> _refreshRunFromDb({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) {
      setState(() => _isLoadingRun = true);
    }
    
    final run = await _runService.getRun(_runId, userId: widget.userId);
    if (run != null && mounted) {
      setState(() {
        _nameController.text = run['name'] ?? 'Palengke Run';
        _budgetController.text = (run['budget'] ?? 2000).toString();
        _status = run['status'] ?? 'draft';
        final rawItems = (run['grocery_run_items'] as List?) ?? [];
        _draftItems = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoadingRun = false;
      });
    } else {
      if (mounted) setState(() => _isLoadingRun = false);
    }
  }

  double get _budget => double.tryParse(_budgetController.text) ?? 0.0;

  double get _totalSpent => _draftItems.fold(
        0.0,
        (sum, item) => sum + (_parsePrice(item['price']) * _parseQty(item['quantity'])),
      );

  int get _totalItems => _draftItems.fold(
        0,
        (sum, item) => sum + ((item['quantity'] as num? ?? 1).toInt()),
      );

  Future<void> _loadLocationPrices() async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final results = await _dbService.searchPrices(
        query: _searchController.text.trim(),
        category: _selectedCategory,
        market: widget.detectedCity,
        province: widget.detectedProvince,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // SSOT: Writes to database first, then reloads UI state from DB
  Future<void> _addItemToDraft({
    required Map<String, dynamic> item,
    required double quantity,
    required String unit,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adding item to run...'), duration: Duration(milliseconds: 500)),
    );

    await _runService.addRunItem(
      runId: _runId,
      item: item,
      quantity: quantity,
      unit: unit,
      userId: widget.userId,
    );

    await _refreshRunFromDb(isSilent: true);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${item['commodity'] ?? 'item'} to list!'),
          backgroundColor: const Color(0xFF0D5C2C),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // SSOT: Qty updates write directly to DB, then reload
  Future<void> _updateQuantity(String commodity, double delta) async {
    final item = _draftItems.firstWhere((i) => i['commodity'] == commodity);
    final currentQty = (item['quantity'] as num? ?? 1).toDouble();
    final newQty = currentQty + delta;

    await _runService.updateRunItemQty(
      runId: _runId,
      commodity: commodity,
      newQty: newQty,
      userId: widget.userId,
    );

    await _refreshRunFromDb(isSilent: true);
  }

  // SSOT: Checked status updates write directly to DB, then reload
  Future<void> _toggleChecked(String commodity, bool checked) async {
    await _runService.updateRunItemChecked(
      runId: _runId,
      commodity: commodity,
      checked: checked,
      userId: widget.userId,
    );

    await _refreshRunFromDb(isSilent: true);
  }

  // SSOT: Start run updates database status directly, then refreshes page
  Future<void> _startShoppingMode() async {
    await _runService.updateRunStatus(
      runId: _runId,
      status: 'active',
      userId: widget.userId,
    );

    await _refreshRunFromDb();
  }

  // SSOT: Finish run completes transaction in database, then pops
  Future<void> _finishShoppingRun() async {
    await _runService.updateRunStatus(
      runId: _runId,
      status: 'completed',
      userId: widget.userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grocery Run completed & saved to history! 🎉'),
          backgroundColor: Color(0xFF0D5C2C),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showAddQuantityModal(Map<String, dynamic> item) {
    double quantity = 1;
    String selectedUnit = item['unit'] ?? 'KG';
    final double price = (item['price'] as num? ?? 0.0).toDouble();

    final modalCardBg = ThemeService.instance.cardBg;
    final modalTextColor = ThemeService.instance.cardText;
    final modalSubText = ThemeService.instance.subText;
    final modalGreen = ThemeService.instance.greenText;
    final modalBtnBg = ThemeService.instance.primaryButtonBg;
    final modalBtnText = ThemeService.instance.primaryButtonText;
    final modalFieldFill = ThemeService.instance.background;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double subtotal = price * quantity;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: modalSubText.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item['commodity'] ?? 'Grocery Item',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: modalTextColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱${price.toStringAsFixed(2)} per $selectedUnit • ${item['market'] ?? widget.detectedCity ?? 'Local Market'}',
                    style: TextStyle(color: modalGreen, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Text('Select Quantity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: modalTextColor)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: quantity > 0.5
                            ? () {
                                setModalState(() {
                                  quantity = (quantity - 0.5).clamp(0.5, 99.0);
                                });
                              }
                            : null,
                        icon: Icon(Icons.remove_circle_outline, size: 28, color: modalGreen),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: modalFieldFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: modalSubText.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${quantity % 1 == 0 ? quantity.toInt() : quantity.toStringAsFixed(1)} $selectedUnit',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: modalTextColor),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setModalState(() {
                            quantity += 0.5;
                          });
                        },
                        icon: Icon(Icons.add_circle_outline, size: 28, color: modalGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Subtotal:', style: TextStyle(fontSize: 14, color: modalSubText)),
                      Text(
                        '₱${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: modalGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _addItemToDraft(item: item, quantity: quantity, unit: selectedUnit);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: modalBtnBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Add to Grocery Run (₱${subtotal.toStringAsFixed(2)})',
                        style: TextStyle(color: modalBtnText, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = ThemeService.instance.background;
    final greenColor = ThemeService.instance.greenText;

    if (_isLoadingRun) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: greenColor)),
      );
    }

    return _status == 'active' ? _buildShoppingModeUI() : _buildBuilderDraftUI();
  }

  // --- UI Layout 1: Building / Drafting mode ---
  Widget _buildBuilderDraftUI() {
    final bool isOverBudget = _totalSpent > _budget && _budget > 0;
    final bgColor = ThemeService.instance.background;
    final cardBg = ThemeService.instance.cardBg;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textThemeColor),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nameController.text.isEmpty ? 'Build Grocery Run' : _nameController.text,
              style: TextStyle(color: textThemeColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.detectedCity ?? widget.detectedProvince ?? 'Local Prices',
              style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildBudgetDashboardCard(isOverBudget),
          _buildToggleTabBar(),
          if (_selectedTabIndex == 0) _buildSearchSection(),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildExplorePricesList()
                : _buildDraftItemList(),
          ),
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  // --- UI Layout 2: Shopping Mode (Matched directly to screenshot) ---
  Widget _buildShoppingModeUI() {
    final double remaining = _budget - _totalSpent;
    final double progress = _budget > 0 ? (_totalSpent / _budget).clamp(0.0, 1.0) : 0.0;
    final int progressPercent = (progress * 100).toInt();

    // Separate checked vs unchecked items
    final uncheckedItems = _draftItems.where((item) {
      final checked = item['checked'] as bool? ?? false;
      if (_activeCategoryFilter == 'All') return !checked;
      return !checked && (item['category'] ?? '').toString().toLowerCase().contains(_activeCategoryFilter!.toLowerCase());
    }).toList();

    final checkedItems = _draftItems.where((item) => item['checked'] as bool? ?? false).toList();
    final double checkedTotal = checkedItems.fold(0.0, (sum, item) => sum + ((item['price'] as num? ?? 0.0).toDouble() * (item['quantity'] as num? ?? 1).toDouble()));

    final bgColor = ThemeService.instance.background;
    final cardBg = ThemeService.instance.cardBg;
    final textColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final greenColor = ThemeService.instance.greenText;
    final btnBg = ThemeService.instance.primaryButtonBg;
    final btnText = ThemeService.instance.primaryButtonText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Shopping Mode (Active)',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // 1. Premium GPS Location Spent Header
          Container(
            color: cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: greenColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Kamusta, ${_nameController.text}! 👋',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: greenColor),
                        ),
                      ],
                    ),
                    Icon(Icons.account_circle_outlined, color: subText),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROGRESS: $progressPercent%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subText),
                        ),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Spent: ',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              TextSpan(
                                text: '₱${_totalSpent.toStringAsFixed(0)} / ₱${_budget.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: greenColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Sakto ra!',
                        style: TextStyle(color: greenColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedProgressBar(
                  value: progress,
                  color: greenColor,
                  backgroundColor: subText.withOpacity(0.15),
                ),
              ],
            ),
          ),

          // 2. Alert Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E824C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sakto ra! Nagpabilin pa ug ₱${remaining.toStringAsFixed(0)} sa imong budget. Kaya pa ang dugang!',
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // 3. Category Filter Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All', 'Tanang Items'),
                _buildFilterChip('Meat', 'Meat & Poultry'),
                _buildFilterChip('Vegetables', 'Vegetables'),
                _buildFilterChip('Eggs', 'Eggs'),
                _buildFilterChip('Rice', 'Rice'),
              ],
            ),
          ),

          // 4. Shopping Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Unchecked active items
                ...uncheckedItems.map((item) => _buildShoppingItemCard(item)),

                const SizedBox(height: 16),

                // Collapsible purchased items list
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Purchased (${checkedItems.length} items)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                        ),
                        Text(
                          '₱${checkedTotal.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: subText),
                        ),
                      ],
                    ),
                    children: checkedItems.map((item) => _buildShoppingItemCard(item)).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 5. Floating Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            color: cardBg,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _finishShoppingRun,
                  icon: Icon(Icons.receipt_long, color: btnText),
                  label: Text(
                    'Tapos na ang Grocery Run',
                    style: TextStyle(color: btnText, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final bool isSelected = _activeCategoryFilter == value;
    final greenColor = ThemeService.instance.greenText;
    final cardText = ThemeService.instance.cardText;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: greenColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : cardText,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _activeCategoryFilter = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildShoppingItemCard(Map<String, dynamic> item) {
    final String itemId = (item['id'] ?? '').toString();
    final String syncStatus = item['sync_status'] ?? 'synced';
    final bool isItemUnsynced = syncStatus != 'synced' || double.tryParse(itemId) != null;
    final String commodity = item['commodity'] ?? 'Item';
    final double price = (item['price'] as num? ?? 0.0).toDouble();
    final double qty = (item['quantity'] as num? ?? 1).toDouble();
    final String unit = item['unit'] ?? 'KG';
    final bool isChecked = item['checked'] as bool? ?? false;
    final double lineTotal = price * qty;
    final market = item['market'] ?? 'Local Market';
    final cardBg = ThemeService.instance.cardBg;
    final textColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final greenColor = ThemeService.instance.greenText;
    final checkedBg = ThemeService.instance.isDarkMode.value
        ? Colors.grey.shade800
        : Colors.grey.shade50;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isChecked ? checkedBg : cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isChecked ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              activeColor: greenColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                if (val != null) {
                  _toggleChecked(commodity, val);
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                            color: isChecked ? subText : textColor,
                          ),
                          child: Text(commodity, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      if (isItemUnsynced) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.cloud_upload_outlined,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${qty % 1 == 0 ? qty.toInt() : qty} $unit • $market',
                    style: TextStyle(color: subText, fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isChecked ? subText : greenColor,
              ),
              child: Text('₱${lineTotal.toStringAsFixed(2)}'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sub-widgets for planning mode ---
  Widget _buildBudgetDashboardCard(bool isOverBudget) {
    final double remaining = _budget - _totalSpent;
    final double progress = _budget > 0 ? (_totalSpent / _budget).clamp(0.0, 1.0) : 0.0;
    final cardBg = ThemeService.instance.cardBg;
    final textColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final greenColor = ThemeService.instance.greenText;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTIMATED TOTAL',
                    style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  AnimatedCount(
                    value: _totalSpent,
                    prefix: '₱',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isOverBudget ? Colors.red : greenColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'BUDGET TARGET',
                    style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₱${_budget.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedProgressBar(
            value: progress,
            height: 10,
            color: isOverBudget ? Colors.red : greenColor,
            backgroundColor: subText.withOpacity(0.15),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_totalItems item${_totalItems == 1 ? '' : 's'} in list',
                style: TextStyle(color: subText, fontSize: 12),
              ),
              Text(
                isOverBudget
                    ? 'Over budget by ₱${(remaining.abs()).toStringAsFixed(2)}'
                    : '₱${remaining.toStringAsFixed(2)} remaining',
                style: TextStyle(
                  color: isOverBudget ? Colors.red : greenColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTabBar() {
    final greenColor = ThemeService.instance.greenText;
    final subText = ThemeService.instance.subText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final tabBarBg = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final activeTabBg = isDark ? Colors.grey.shade700 : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tabBarBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0 ? activeTabBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTabIndex == 0
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                      : null,
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _selectedTabIndex == 0 ? greenColor : subText,
                    ),
                    child: Text('Explore Prices (${_searchResults.length})'),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1 ? activeTabBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTabIndex == 1
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                      : null,
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _selectedTabIndex == 1 ? greenColor : subText,
                    ),
                    child: Text('My Grocery List ($_totalItems)'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    final cardBg = ThemeService.instance.cardBg;
    final greenColor = ThemeService.instance.greenText;
    final textColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: textColor),
            onChanged: (_) => _loadLocationPrices(),
            decoration: InputDecoration(
              hintText: 'Search prices (e.g. Rice, Egg, Pork)...',
              hintStyle: TextStyle(color: subText),
              prefixIcon: Icon(Icons.search, color: greenColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: subText),
                      onPressed: () {
                        _searchController.clear();
                        _loadLocationPrices();
                      },
                    )
                  : null,
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: greenColor.withOpacity(0.15),
                    checkmarkColor: greenColor,
                    labelStyle: TextStyle(
                      color: isSelected ? greenColor : textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? cat : null;
                      });
                      _loadLocationPrices();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorePricesList() {
    final greenColor = ThemeService.instance.greenText;
    final cardText = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final btnBg = ThemeService.instance.primaryButtonBg;
    final btnText = ThemeService.instance.primaryButtonText;

    if (_isSearching) {
      return Center(child: CircularProgressIndicator(color: greenColor));
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No commodity entries found.', style: TextStyle(color: subText)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final commodity = item['commodity'] ?? 'Item';
        final double price = (item['price'] as num? ?? 0.0).toDouble();
        final unit = item['unit'] ?? 'KG';
        final market = item['market'] ?? widget.detectedCity ?? 'Local Market';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: greenColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag_outlined, color: greenColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(commodity, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cardText)),
                      const SizedBox(height: 2),
                      Text(
                        '₱${price.toStringAsFixed(2)} / $unit',
                        style: TextStyle(color: greenColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        market,
                        style: TextStyle(color: subText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddQuantityModal(item),
                  icon: Icon(Icons.add, size: 16, color: btnText),
                  label: Text('Add', style: TextStyle(color: btnText, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraftItemList() {
    final textColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final qtyBg = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final qtyIconColor = ThemeService.instance.cardText;

    if (_draftItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.playlist_add, size: 64, color: subText),
              const SizedBox(height: 12),
              Text(
                'Your list is empty',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Switch to "Explore Prices" tab to browse local market prices and add items into your run!',
                style: TextStyle(color: subText, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _draftItems.length,
      itemBuilder: (context, index) {
        final item = _draftItems[index];
        final String itemId = (item['id'] ?? '').toString();
        final String syncStatus = item['sync_status'] ?? 'synced';
        final bool isItemUnsynced = syncStatus != 'synced' || double.tryParse(itemId) != null;
        final String commodity = item['commodity'] ?? 'Item';
        final double price = (item['price'] as num? ?? 0.0).toDouble();
        final double qty = (item['quantity'] as num? ?? 1).toDouble();
        final String unit = item['unit'] ?? 'KG';
        final double lineTotal = price * qty;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              commodity,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isItemUnsynced) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.cloud_upload_outlined,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '₱${price.toStringAsFixed(2)} × ${qty % 1 == 0 ? qty.toInt() : qty} $unit = ₱${lineTotal.toStringAsFixed(2)}',
                        style: TextStyle(color: subText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: qtyBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18, color: qtyIconColor),
                        onPressed: () => _updateQuantity(commodity, -1),
                      ),
                      Text(
                        '${qty % 1 == 0 ? qty.toInt() : qty}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 18, color: qtyIconColor),
                        onPressed: () => _updateQuantity(commodity, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar() {
    final cardBg = ThemeService.instance.cardBg;
    final greenColor = ThemeService.instance.greenText;
    final btnBg = ThemeService.instance.primaryButtonBg;
    final btnText = ThemeService.instance.primaryButtonText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: Icon(Icons.save_outlined, color: greenColor),
                label: Text('Back to Runs', style: TextStyle(color: greenColor, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: greenColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startShoppingMode,
                icon: Icon(Icons.play_arrow, color: btnText),
                label: Text(
                  'Start Shopping Run',
                  style: TextStyle(color: btnText, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
