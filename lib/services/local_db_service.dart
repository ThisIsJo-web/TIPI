import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;

  LocalDbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tipi_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // If the database does not exist in the documents directory,
    // we copy it from assets (or in a real case, download it).
    if (!await databaseExists(path)) {
      try {
        // Ensure parent directory exists
        await Directory(dirname(path)).create(recursive: true);
        
        // Copy from assets
        ByteData data = await rootBundle.load("assets/$filePath");
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        debugPrint("Database copied from assets to: $path");
      } catch (e) {
        debugPrint("Database copy failed (we might need to download it): $e");
      }
    }

    return await openDatabase(path, readOnly: true);
  }

  // Check if local database file actually exists on device
  Future<bool> databaseFileExists() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tipi_data.db');
    return await File(path).exists();
  }

  // Force overwrite database file (used by update system)
  Future<void> overwriteDatabase(List<int> bytes) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tipi_data.db');
    
    // Close existing connection if open
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    await File(path).writeAsBytes(bytes, flush: true);
    debugPrint("Database overwritten successfully with updated file.");
  }

  Future<List<Map<String, dynamic>>> searchPrices({
    String? query,
    String? category,
    String? market,
    String? province,
    int limit = 100,
  }) async {
    final db = await database;
    
    Future<List<Map<String, dynamic>>> executeQuery(String? mkt, String? prov) async {
      List<String> whereClauses = [];
      List<dynamic> whereArgs = [];
      
      if (query != null && query.isNotEmpty) {
        whereClauses.add("commodity LIKE ?");
        whereArgs.add("%$query%");
      }
      
      if (category != null && category.isNotEmpty) {
        whereClauses.add("category = ?");
        whereArgs.add(category);
      }
      
      if (mkt != null && mkt.isNotEmpty) {
        whereClauses.add("market = ?");
        whereArgs.add(mkt);
      }
  
      if (prov != null && prov.isNotEmpty) {
        whereClauses.add("admin2 = ?");
        whereArgs.add(prov);
      }
      
      String whereString = whereClauses.isNotEmpty 
          ? "WHERE ${whereClauses.join(" AND ")}" 
          : "";
           
      return await db.rawQuery('''
        SELECT * FROM prices
        $whereString
        ORDER BY date DESC, price ASC
        LIMIT ?
      ''', [...whereArgs, limit]);
    }

    // Try 1: Exact search (both market and province)
    var results = await executeQuery(market, province);
    if (results.isNotEmpty) return results;

    // Try 2: Fallback to Province only
    if (market != null && market.isNotEmpty) {
      results = await executeQuery(null, province);
      if (results.isNotEmpty) return results;
    }

    // Try 3: Fallback to global search (no location filters)
    return await executeQuery(null, null);
  }

  // Get distinct list of provinces
  Future<List<String>> getProvinces() async {
    final db = await database;
    final res = await db.rawQuery('SELECT DISTINCT admin2 FROM prices WHERE admin2 IS NOT NULL AND admin2 != "" ORDER BY admin2 ASC');
    return res.map((r) => r['admin2'] as String).toList();
  }

  // Get distinct list of markets (optionally filtered by province)
  Future<List<String>> getMarkets({String? province}) async {
    final db = await database;
    final hasProvince = province != null && province.isNotEmpty;
    final res = await db.rawQuery(
      'SELECT DISTINCT market FROM prices WHERE ${hasProvince ? "admin2 = ? AND " : ""}market IS NOT NULL AND market != "" ORDER BY market ASC',
      hasProvince ? [province] : null,
    );
    return res.map((r) => r['market'] as String).toList();
  }

  // Get nearest location details based on GPS coordinates
  Future<Map<String, String>?> getNearestLocation(double lat, double lng) async {
    final db = await database;
    const double delta = 0.2; // Bounding box range (~22km)
    
    // Optimize search using bounding box to prevent full table scans
    var results = await db.rawQuery('''
      SELECT admin2, market, admin1, 
             ((latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?)) AS distance
      FROM prices
      WHERE latitude BETWEEN ? AND ? 
        AND longitude BETWEEN ? AND ?
        AND admin2 IS NOT NULL AND admin2 != ""
      ORDER BY distance ASC
      LIMIT 1
    ''', [lat, lat, lng, lng, lat - delta, lat + delta, lng - delta, lng + delta]);
    
    // Fallback to full table scan if bounding box yielded no records
    if (results.isEmpty) {
      results = await db.rawQuery('''
        SELECT admin2, market, admin1, 
               ((latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?)) AS distance
        FROM prices
        WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND admin2 IS NOT NULL AND admin2 != ""
        ORDER BY distance ASC
        LIMIT 1
      ''', [lat, lat, lng, lng]);
    }
    
    if (results.isNotEmpty) {
      return {
        'province': results.first['admin2'] as String? ?? '',
        'city': results.first['market'] as String? ?? '',
        'region': results.first['admin1'] as String? ?? '',
      };
    }
    return null;
  }

  // Get distinct list of categories
  Future<List<String>> getCategories() async {
    final db = await database;
    final res = await db.rawQuery('SELECT DISTINCT category FROM prices ORDER BY category ASC');
    return res.map((r) => r['category'] as String).toList();
  }

  // Get price trend over time for a specific commodity in a specific market
  Future<List<Map<String, dynamic>>> getPriceTrend(String commodity, String market) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT date, price FROM prices
      WHERE commodity = ? AND market = ?
      ORDER BY date ASC
    ''', [commodity, market]);
  }
}
