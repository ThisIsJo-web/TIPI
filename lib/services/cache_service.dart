import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import '../models/price_item.dart';

class CacheService {
  static final CacheService instance = CacheService._init();
  CacheService._init();

  List<PriceItem> _cachedPrices = [];
  bool _isInitialized = false;

  static final List<PriceItem> defaultPrices = [
    // Cereals
    PriceItem(commodity: "Rice (Regular Milled)", category: "Cereals", price: 50.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Rice (Well Milled)", category: "Cereals", price: 54.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Rice (Special/Premium)", category: "Cereals", price: 60.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Rice (Regular Milled)", category: "Cereals", price: 49.00, unit: "kg", market: "Panabo Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Rice (Well Milled)", category: "Cereals", price: 53.00, unit: "kg", market: "Panabo Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Corn (Grits/Grain)", category: "Cereals", price: 35.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),

    // Meat, Fish and Poultry
    PriceItem(commodity: "Pork (Pigue/Kasim)", category: "Meat, Fish and Poultry", price: 320.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Pork (Liempo)", category: "Meat, Fish and Poultry", price: 350.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Pork (Pigue/Kasim)", category: "Meat, Fish and Poultry", price: 315.00, unit: "kg", market: "Panabo Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Beef (Meat with bone)", category: "Meat, Fish and Poultry", price: 380.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Chicken (Fully Dressed)", category: "Meat, Fish and Poultry", price: 180.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Chicken (Fully Dressed)", category: "Meat, Fish and Poultry", price: 175.00, unit: "kg", market: "Panabo Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Chicken Eggs (Medium)", category: "Meat, Fish and Poultry", price: 8.50, unit: "pc", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Milkfish (Bangus)", category: "Meat, Fish and Poultry", price: 180.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Tilapia", category: "Meat, Fish and Poultry", price: 140.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Round Scad (Galunggong)", category: "Meat, Fish and Poultry", price: 200.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),

    // Vegetables and Fruits
    PriceItem(commodity: "Red Onion", category: "Vegetables and Fruits", price: 120.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "White Onion", category: "Vegetables and Fruits", price: 110.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Garlic (Imported)", category: "Vegetables and Fruits", price: 140.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Tomatoes", category: "Vegetables and Fruits", price: 70.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Cabbage", category: "Vegetables and Fruits", price: 80.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Carrots", category: "Vegetables and Fruits", price: 90.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Potatoes", category: "Vegetables and Fruits", price: 100.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Eggplant", category: "Vegetables and Fruits", price: 60.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Ampalaya (Bitter Gourd)", category: "Vegetables and Fruits", price: 75.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Banana (Lakatan)", category: "Vegetables and Fruits", price: 70.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),

    // Milk and Dairy
    PriceItem(commodity: "Powdered Milk (330g)", category: "Milk and Dairy", price: 145.00, unit: "pack", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Evaporated Milk (370ml)", category: "Milk and Dairy", price: 45.00, unit: "can", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),

    // Miscellaneous
    PriceItem(commodity: "Cooking Oil (Palm)", category: "Miscellaneous", price: 85.00, unit: "L", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Refined Sugar", category: "Miscellaneous", price: 85.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Brown Sugar", category: "Miscellaneous", price: 75.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
    PriceItem(commodity: "Iodized Salt", category: "Miscellaneous", price: 25.00, unit: "kg", market: "Tagum Public Market", admin2: "Davao del Norte", date: "2026-06-15"),
  ];

  List<PriceItem> get cachedPrices => _cachedPrices.isNotEmpty ? _cachedPrices : defaultPrices;

  // Retrieve file path to save cached data
  Future<File> get _cacheFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/dataset_cache.json');
  }

  Future<File> get _versionFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/dataset_version.json');
  }

  // Initialize service: tries to load from local cache file first
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _cacheFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List parsed = jsonDecode(content);
        final loaded = parsed.map((item) => PriceItem.fromJson(item)).toList();
        if (loaded.isNotEmpty) {
          _cachedPrices = loaded;
        } else {
          _cachedPrices = List.from(defaultPrices);
        }
        debugPrint("Loaded ${_cachedPrices.length} records from local cache.");
      } else {
        _cachedPrices = List.from(defaultPrices);
      }
    } catch (e) {
      debugPrint("Error loading local dataset cache: $e");
      _cachedPrices = List.from(defaultPrices);
    }
    _isInitialized = true;
  }

  // Sync cache with backend API if out of date
  Future<bool> syncDataset() async {
    await init();
    try {
      // 1. Fetch remote version
      final remoteVersion = await ApiService.instance.fetchDatasetVersion();
      if (remoteVersion == null) {
        debugPrint("Could not check dataset version. Using local cache.");
        return cachedPrices.isNotEmpty;
      }

      // 2. Read local version
      Map<String, dynamic>? localVersion;
      final verFile = await _versionFile;
      if (await verFile.exists()) {
        final content = await verFile.readAsString();
        localVersion = jsonDecode(content) as Map<String, dynamic>;
      }

      // 3. Compare version timestamp/dates
      final String remoteDate = remoteVersion['releaseDate'] ?? '';
      final String localDate = localVersion != null ? (localVersion['releaseDate'] ?? '') : '';

      if (_cachedPrices.isEmpty || remoteDate != localDate) {
        debugPrint("Syncing prices: Local ($localDate) != Remote ($remoteDate). Fetching...");
        
        // 4. Fetch full dataset
        final newPrices = await ApiService.instance.fetchPriceDataset();
        if (newPrices.isNotEmpty) {
          _cachedPrices = newPrices;

          // Save cache to disk
          final file = await _cacheFile;
          await file.writeAsString(jsonEncode(_cachedPrices.map((p) => p.toJson()).toList()));
          
          // Save version to disk
          await verFile.writeAsString(jsonEncode(remoteVersion));
          
          debugPrint("Synced and cached ${newPrices.length} records successfully.");
          return true;
        }
      } else {
        debugPrint("Dataset is up to date. Version date: $localDate");
        return true;
      }
    } catch (e) {
      debugPrint("Error syncing dataset: $e");
    }
    return cachedPrices.isNotEmpty;
  }
}
