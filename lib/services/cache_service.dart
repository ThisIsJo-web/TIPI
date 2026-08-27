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

  List<PriceItem> get cachedPrices => _cachedPrices;

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
        _cachedPrices = parsed.map((item) => PriceItem.fromJson(item)).toList();
        debugPrint("Loaded ${_cachedPrices.length} records from local cache.");
      }
    } catch (e) {
      debugPrint("Error loading local dataset cache: $e");
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
        return _cachedPrices.isNotEmpty;
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
    return _cachedPrices.isNotEmpty;
  }
}
