import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'telemetry_service.dart';

class GroceryRunService {
  static final GroceryRunService instance = GroceryRunService._init();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Database? _cacheDb;

  GroceryRunService._init() {
    // Start periodic background sync worker
    Timer.periodic(const Duration(seconds: 30), (timer) {
      syncPendingChanges();
    });
  }

  final _runUpdateController = StreamController<void>.broadcast();
  Stream<void> get onRunUpdated => _runUpdateController.stream;

  void notifyListeners() {
    _runUpdateController.add(null);
  }

  // Get cache database instance
  Future<Database> get cacheDb async {
    if (_cacheDb != null) return _cacheDb!;
    _cacheDb = await _initCacheDb();
    return _cacheDb!;
  }

  Future<Database> _initCacheDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'tipi_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_runs (
              id TEXT PRIMARY KEY,
              user_id TEXT,
              name TEXT,
              budget REAL,
              spent REAL,
              status TEXT,
              created_at TEXT,
              updated_at TEXT,
              deleted_at TEXT,
              sync_status TEXT DEFAULT 'synced'
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_items (
              id TEXT PRIMARY KEY,
              run_id TEXT,
              commodity TEXT,
              price REAL,
              quantity REAL,
              unit TEXT,
              category TEXT,
              market TEXT,
              checked INTEGER,
              created_at TEXT,
              deleted_at TEXT,
              sync_status TEXT DEFAULT 'synced'
          )
        ''');
      },
    );
  }

  // Check if a run or item is unsynced based on temp ID format (millis since epoch)
  bool isTempId(String id) {
    return double.tryParse(id) != null;
  }

  // Helper to map DB row to service Map
  Map<String, dynamic> _mapRun(
    Map<String, dynamic> runRow,
    List<Map<String, dynamic>> itemRows,
  ) {
    final run = Map<String, dynamic>.from(runRow);
    run['grocery_run_items'] = itemRows.map((i) {
      final item = Map<String, dynamic>.from(i);
      item['checked'] = item['checked'] == 1;
      return item;
    }).toList();
    return run;
  }

  // Shared database upsert helpers
  Future<void> _upsertRunToCache(DatabaseExecutor executor, Map<String, dynamic> run, {String syncStatus = 'synced'}) async {
    await executor.insert('cached_runs', {
      'id': run['id'],
      'user_id': run['user_id'],
      'name': run['name'],
      'budget': (run['budget'] as num).toDouble(),
      'spent': (run['spent'] as num).toDouble(),
      'status': run['status'],
      'created_at': run['created_at'],
      'updated_at': run['updated_at'],
      'sync_status': syncStatus,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _upsertItemToCache(DatabaseExecutor executor, Map<String, dynamic> item, {String syncStatus = 'synced'}) async {
    final String itemId = (item['id'] ?? '').toString();
    final String runId = (item['run_id'] ?? '').toString();
    final String commodity = item['commodity'] ?? '';

    if (!isTempId(itemId) && runId.isNotEmpty && commodity.isNotEmpty) {
      final tempItems = await executor.query(
        'cached_items',
        where: 'run_id = ? AND commodity = ?',
        whereArgs: [runId, commodity],
      );
      for (var temp in tempItems) {
        final tempId = temp['id'].toString();
        if (isTempId(tempId) && tempId != itemId) {
          await executor.delete(
            'cached_items',
            where: 'id = ?',
            whereArgs: [tempId],
          );
        }
      }
    }

    await executor.insert('cached_items', {
      'id': item['id'],
      'run_id': item['run_id'],
      'commodity': item['commodity'],
      'price': (item['price'] as num).toDouble(),
      'quantity': (item['quantity'] as num).toDouble(),
      'unit': item['unit'],
      'category': item['category'],
      'market': item['market'],
      'checked': item['checked'] == true || item['checked'] == 1 ? 1 : 0,
      'created_at': item['created_at'],
      'sync_status': syncStatus,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> _fetchLocalRuns(Database db, String? userId) async {
    final localRunRows = await db.query(
      'cached_runs',
      where: 'deleted_at IS NULL AND (user_id = ? OR user_id IS NULL)',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    List<Map<String, dynamic>> localRuns = [];
    for (var rRow in localRunRows) {
      final iRows = await db.query(
        'cached_items',
        where: 'run_id = ? AND deleted_at IS NULL',
        whereArgs: [rRow['id']],
      );
      localRuns.add(_mapRun(rRow, iRows));
    }
    return localRuns;
  }

  // Get all grocery runs (merging local SQLite cache & Supabase)
  Future<List<Map<String, dynamic>>> getRuns(String? userId) async {
    final db = await cacheDb;
    final localRuns = await _fetchLocalRuns(db, userId);

    if (userId == null || userId.isEmpty || _client == null) {
      return localRuns;
    }

    try {
      final response = await _client!
          .from('grocery_runs')
          .select('*, grocery_run_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> remoteRuns =
          List<Map<String, dynamic>>.from(response);

      // Save remote runs into local cache
      await db.transaction((txn) async {
        for (var run in remoteRuns) {
          await _upsertRunToCache(txn, run);

          final List items = run['grocery_run_items'] ?? [];
          for (var item in items) {
            await _upsertItemToCache(txn, Map<String, dynamic>.from(item));
          }
        }
      });

      return await _fetchLocalRuns(db, userId);
    } catch (e, stack) {
      TelemetryService.instance.logError(e, stack, "fetching grocery runs");
      return localRuns;
    }
  }

  // Get single run with its items list
  Future<Map<String, dynamic>?> getRun(String runId, {String? userId}) async {
    final db = await cacheDb;
    final runRows = await db.query(
      'cached_runs',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [runId],
    );
    if (runRows.isEmpty) return null;

    final itemRows = await db.query(
      'cached_items',
      where: 'run_id = ? AND deleted_at IS NULL',
      whereArgs: [runId],
    );
    final localRun = _mapRun(runRows.first, itemRows);

    if (userId == null || userId.isEmpty || _client == null) {
      return localRun;
    }

    try {
      final response = await _client!
          .from('grocery_runs')
          .select('*, grocery_run_items(*)')
          .eq('id', runId)
          .maybeSingle();

      if (response != null) {
        await db.transaction((txn) async {
          await _upsertRunToCache(txn, response);

          final List items = response['grocery_run_items'] ?? [];
          for (var item in items) {
            await _upsertItemToCache(txn, Map<String, dynamic>.from(item));
          }
        });

        final updatedItemRows = await db.query(
          'cached_items',
          where: 'run_id = ? AND deleted_at IS NULL',
          whereArgs: [runId],
        );
        return _mapRun(response, updatedItemRows);
      }
    } catch (e, stack) {
      TelemetryService.instance.logError(
        e,
        stack,
        "fetching single grocery run",
      );
    }

    return localRun;
  }

  // Get active run
  Future<Map<String, dynamic>?> getActiveRun(String? userId) async {
    final runs = await getRuns(userId);
    try {
      final active = runs.where((r) => r['status'] != 'completed').toList();
      return active.isNotEmpty ? active.first : null;
    } catch (e) {
      return null;
    }
  }

  // Create run header
  Future<Map<String, dynamic>?> createRunHeader({
    required String? userId,
    required String name,
    required double budget,
  }) async {
    final db = await cacheDb;
    final String tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final String nowStr = DateTime.now().toIso8601String();

    await _upsertRunToCache(db, {
      'id': tempId,
      'user_id': userId,
      'name': name,
      'budget': budget,
      'spent': 0.0,
      'status': 'draft',
      'created_at': nowStr,
      'updated_at': nowStr,
    }, syncStatus: 'pending_insert');

    final newRun = <String, dynamic>{
      'id': tempId,
      'user_id': userId,
      'name': name,
      'budget': budget,
      'spent': 0.0,
      'status': 'draft',
      'created_at': nowStr,
      'grocery_run_items': <Map<String, dynamic>>[],
    };

    if (userId != null && userId.isNotEmpty && _client != null) {
      try {
        final runData = await _client!
            .from('grocery_runs')
            .insert({
              'user_id': userId,
              'name': name,
              'budget': budget,
              'spent': 0.0,
              'status': 'draft',
            })
            .select()
            .single();

        await db.transaction((txn) async {
          await txn.delete('cached_runs', where: 'id = ?', whereArgs: [tempId]);
          await _upsertRunToCache(txn, {
            'id': runData['id'],
            'user_id': userId,
            'name': name,
            'budget': budget,
            'spent': 0.0,
            'status': 'draft',
            'created_at': nowStr,
            'updated_at': nowStr,
          });
        });

        newRun['id'] = runData['id'];
      } catch (e, stack) {
        TelemetryService.instance.logError(
          e,
          stack,
          "creating remote run header",
        );
      }
    }

    notifyListeners();
    return newRun;
  }

  // Add run item
  Future<void> addRunItem({
    required String runId,
    required Map<String, dynamic> item,
    required double quantity,
    required String unit,
    String? userId,
  }) async {
    final db = await cacheDb;
    final String commodity = item['commodity'] ?? item['name'] ?? 'Item';
    final double price = (item['price'] as num? ?? 0.0).toDouble();
    final String itemId = DateTime.now().millisecondsSinceEpoch.toString();

    // Check if item already exists locally in this run
    final existing = await db.query(
      'cached_items',
      where: 'run_id = ? AND commodity = ? AND deleted_at IS NULL',
      whereArgs: [runId, commodity],
    );

    if (existing.isNotEmpty) {
      final currentQty = (existing.first['quantity'] as num).toDouble();
      await db.update(
        'cached_items',
        {
          'quantity': currentQty + quantity,
          'sync_status': isTempId(runId) ? 'pending_insert' : 'pending_update',
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('cached_items', {
        'id': itemId,
        'run_id': runId,
        'commodity': commodity,
        'price': price,
        'quantity': quantity,
        'unit': unit,
        'category': item['category'],
        'market': item['market'],
        'checked': 0,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending_insert',
      });
    }

    await _recalculateSpentLocal(runId);

    if (_client != null &&
        userId != null &&
        userId.isNotEmpty &&
        !isTempId(runId)) {
      try {
        final existingRemote = await _client!
            .from('grocery_run_items')
            .select()
            .eq('run_id', runId)
            .eq('commodity', commodity)
            .maybeSingle();

        if (existingRemote != null) {
          final currentQty = (existingRemote['quantity'] as num? ?? 1)
              .toDouble();
          await _client!
              .from('grocery_run_items')
              .update({'quantity': currentQty + quantity})
              .eq('id', existingRemote['id']);

          // Update local ID to match the remote ID!
          await db.update(
            'cached_items',
            {
              'id': existingRemote['id'] as String,
              'sync_status': 'synced',
            },
            where: 'run_id = ? AND commodity = ?',
            whereArgs: [runId, commodity],
          );
        } else {
          final newRemote = await _client!.from('grocery_run_items').insert({
            'run_id': runId,
            'commodity': commodity,
            'price': price,
            'quantity': quantity,
            'unit': unit,
            'category': item['category'],
            'market': item['market'],
            'checked': false,
          }).select().single();

          // Update local ID to match the remote ID!
          await db.update(
            'cached_items',
            {
              'id': newRemote['id'] as String,
              'sync_status': 'synced',
            },
            where: 'run_id = ? AND commodity = ?',
            whereArgs: [runId, commodity],
          );
        }
      } catch (e, stack) {
        TelemetryService.instance.logError(e, stack, "syncing added item");
      }
    }

    notifyListeners();
  }

  // Update item qty
  Future<void> updateRunItemQty({
    required String runId,
    required String commodity,
    required double newQty,
    String? userId,
  }) async {
    final db = await cacheDb;

    if (newQty <= 0) {
      await db.update(
        'cached_items',
        {
          'deleted_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending_delete',
        },
        where: 'run_id = ? AND commodity = ?',
        whereArgs: [runId, commodity],
      );
    } else {
      await db.update(
        'cached_items',
        {
          'quantity': newQty,
          'sync_status': isTempId(runId) ? 'pending_insert' : 'pending_update',
        },
        where: 'run_id = ? AND commodity = ?',
        whereArgs: [runId, commodity],
      );
    }

    await _recalculateSpentLocal(runId);

    if (_client != null &&
        userId != null &&
        userId.isNotEmpty &&
        !isTempId(runId)) {
      try {
        if (newQty <= 0) {
          await _client!
              .from('grocery_run_items')
              .delete()
              .eq('run_id', runId)
              .eq('commodity', commodity);
          await db.delete(
            'cached_items',
            where: 'run_id = ? AND commodity = ?',
            whereArgs: [runId, commodity],
          );
        } else {
          await _client!
              .from('grocery_run_items')
              .update({'quantity': newQty})
              .eq('run_id', runId)
              .eq('commodity', commodity);
          await db.update(
            'cached_items',
            {'sync_status': 'synced'},
            where: 'run_id = ? AND commodity = ?',
            whereArgs: [runId, commodity],
          );
        }
      } catch (e, stack) {
        TelemetryService.instance.logError(e, stack, "syncing item qty update");
      }
    }

    notifyListeners();
  }

  // Update checkmark state
  Future<void> updateRunItemChecked({
    required String runId,
    required String commodity,
    required bool checked,
    String? userId,
  }) async {
    final db = await cacheDb;

    await db.update(
      'cached_items',
      {
        'checked': checked ? 1 : 0,
        'sync_status': isTempId(runId) ? 'pending_insert' : 'pending_update',
      },
      where: 'run_id = ? AND commodity = ?',
      whereArgs: [runId, commodity],
    );

    if (_client != null &&
        userId != null &&
        userId.isNotEmpty &&
        !isTempId(runId)) {
      try {
        await _client!
            .from('grocery_run_items')
            .update({'checked': checked})
            .eq('run_id', runId)
            .eq('commodity', commodity);
        await db.update(
          'cached_items',
          {'sync_status': 'synced'},
          where: 'run_id = ? AND commodity = ?',
          whereArgs: [runId, commodity],
        );
      } catch (e, stack) {
        TelemetryService.instance.logError(
          e,
          stack,
          "syncing item checked state",
        );
      }
    }

    notifyListeners();
  }

  // Remove item
  Future<void> removeRunItem({
    required String runId,
    required String commodity,
    String? userId,
  }) async {
    final db = await cacheDb;

    await db.update(
      'cached_items',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending_delete',
      },
      where: 'run_id = ? AND commodity = ?',
      whereArgs: [runId, commodity],
    );

    await _recalculateSpentLocal(runId);

    if (_client != null &&
        userId != null &&
        userId.isNotEmpty &&
        !isTempId(runId)) {
      try {
        await _client!
            .from('grocery_run_items')
            .delete()
            .eq('run_id', runId)
            .eq('commodity', commodity);
        await db.delete(
          'cached_items',
          where: 'run_id = ? AND commodity = ?',
          whereArgs: [runId, commodity],
        );
      } catch (e, stack) {
        TelemetryService.instance.logError(e, stack, "syncing item removal");
      }
    }

    notifyListeners();
  }

  // Local helper to update spent column
  Future<void> _recalculateSpentLocal(String runId) async {
    final db = await cacheDb;
    final itemRows = await db.query(
      'cached_items',
      where: 'run_id = ? AND deleted_at IS NULL',
      whereArgs: [runId],
    );

    final double spent = itemRows.fold<double>(0.0, (sum, item) {
      final double price = (item['price'] as num? ?? 0.0).toDouble();
      final double qty = (item['quantity'] as num? ?? 0.0).toDouble();
      return sum + (price * qty);
    });

    await db.update(
      'cached_runs',
      {
        'spent': spent,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': isTempId(runId) ? 'pending_insert' : 'pending_update',
      },
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  // Update status
  Future<bool> updateRunStatus({
    required String runId,
    required String status,
    String? userId,
  }) async {
    final db = await cacheDb;

    await db.update(
      'cached_runs',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': isTempId(runId) ? 'pending_insert' : 'pending_update',
      },
      where: 'id = ?',
      whereArgs: [runId],
    );

    if (_client != null &&
        userId != null &&
        userId.isNotEmpty &&
        !isTempId(runId)) {
      try {
        await _client!
            .from('grocery_runs')
            .update({
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', runId);

        await db.update(
          'cached_runs',
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [runId],
        );

        if (status == 'completed') {
          try {
            final profile = await _client!
                .from('profiles')
                .select('runs_completed')
                .eq('id', userId)
                .single();
            final currentCompleted = (profile['runs_completed'] as int? ?? 0);
            await _client!
                .from('profiles')
                .update({'runs_completed': currentCompleted + 1})
                .eq('id', userId);
          } catch (_) {}
        }
      } catch (e, stack) {
        TelemetryService.instance.logError(
          e,
          stack,
          "syncing run status update",
        );
      }
    }

    notifyListeners();
    return true;
  }

  // Delete run
  Future<bool> deleteRun(String runId, {String? userId}) async {
    final db = await cacheDb;

    await db.update(
      'cached_runs',
      {
        'deleted_at': DateTime.now().toIso8601String(),
        'sync_status': 'pending_delete',
      },
      where: 'id = ?',
      whereArgs: [runId],
    );

    if (_client != null &&
        userId != null &&
        userId.isNotEmpty &&
        !isTempId(runId)) {
      try {
        await _client!.from('grocery_runs').delete().eq('id', runId);
        await db.delete('cached_runs', where: 'id = ?', whereArgs: [runId]);
      } catch (e, stack) {
        TelemetryService.instance.logError(e, stack, "syncing run deletion");
      }
    }

    notifyListeners();
    return true;
  }

  // Perform background synchronization of cached data
  Future<void> syncPendingChanges() async {
    if (_client == null || _client!.auth.currentUser == null) return;
    final db = await cacheDb;

    try {
      // Early exit check to see if there are any pending changes
      final runPending = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM cached_runs WHERE sync_status != "synced"'
      )) ?? 0;
      final itemPending = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM cached_items WHERE sync_status != "synced"'
      )) ?? 0;

      if (runPending == 0 && itemPending == 0) return;

      // 1. Process pending run deletions
      final deletedRuns = await db.query(
        'cached_runs',
        where: 'sync_status = "pending_delete"',
      );
      for (var run in deletedRuns) {
        final runId = run['id'] as String;
        if (!isTempId(runId)) {
          await _client!.from('grocery_runs').delete().eq('id', runId);
        }
        await db.delete('cached_runs', where: 'id = ?', whereArgs: [runId]);
        await db.delete(
          'cached_items',
          where: 'run_id = ?',
          whereArgs: [runId],
        );
      }

      // 2. Process pending item deletions
      final deletedItems = await db.query(
        'cached_items',
        where: 'sync_status = "pending_delete"',
      );
      for (var item in deletedItems) {
        final itemId = item['id'] as String;
        final runId = item['run_id'] as String;
        if (!isTempId(itemId) && !isTempId(runId)) {
          await _client!
              .from('grocery_run_items')
              .delete()
              .eq('run_id', runId)
              .eq('commodity', item['commodity']!);
        }
        await db.delete('cached_items', where: 'id = ?', whereArgs: [itemId]);
      }

      // 3. Process new runs created offline
      final unsyncedRuns = await db.query(
        'cached_runs',
        where: 'sync_status = "pending_insert"',
      );
      for (var run in unsyncedRuns) {
        final tempId = run['id'] as String;
        if (isTempId(tempId)) {
          // Create remotely
          final runData = await _client!
              .from('grocery_runs')
              .insert({
                'user_id': run['user_id'],
                'name': run['name'],
                'budget': run['budget'],
                'spent': run['spent'],
                'status': run['status'],
              })
              .select()
              .single();

          final remoteId = runData['id'] as String;

          await db.transaction((txn) async {
            // Update items to point to the new remote run ID
            await txn.update(
              'cached_items',
              {'run_id': remoteId},
              where: 'run_id = ?',
              whereArgs: [tempId],
            );
            // Replace run ID
            await txn.delete(
              'cached_runs',
              where: 'id = ?',
              whereArgs: [tempId],
            );
            await _upsertRunToCache(txn, {
              'id': remoteId,
              'user_id': run['user_id'],
              'name': run['name'],
              'budget': run['budget'],
              'spent': run['spent'],
              'status': run['status'],
              'created_at': run['created_at'],
              'updated_at': run['updated_at'],
            });
          });

          // Upload newly mapped items in batch
          final itemsToInsert = await db.query(
            'cached_items',
            where: 'run_id = ?',
            whereArgs: [remoteId],
          );
          if (itemsToInsert.isNotEmpty) {
            final List<Map<String, dynamic>> itemsPayload = itemsToInsert.map((item) => {
              'run_id': remoteId,
              'commodity': item['commodity'],
              'price': item['price'],
              'quantity': item['quantity'],
              'unit': item['unit'],
              'category': item['category'],
              'market': item['market'],
              'checked': item['checked'] == 1,
            }).toList();

            final insertedRemoteItems = await _client!
                .from('grocery_run_items')
                .insert(itemsPayload)
                .select();

            for (var remoteItem in insertedRemoteItems) {
              final String comm = remoteItem['commodity'] as String;
              final String remoteItemId = remoteItem['id'] as String;
              await db.update(
                'cached_items',
                {
                  'id': remoteItemId,
                  'sync_status': 'synced',
                },
                where: 'run_id = ? AND commodity = ?',
                whereArgs: [remoteId, comm],
              );
            }
            
            for (var item in itemsToInsert) {
              await db.update(
                'cached_items',
                {'sync_status': 'synced'},
                where: 'id = ? AND sync_status != ?',
                whereArgs: [item['id'], 'synced'],
              );
            }
          }
        }
      }

      // 4. Process pending updates to already synced runs
      final unsyncedUpdates = await db.query(
        'cached_runs',
        where: 'sync_status = "pending_update"',
      );
      for (var run in unsyncedUpdates) {
        final runId = run['id'] as String;
        if (!isTempId(runId)) {
          await _client!
              .from('grocery_runs')
              .update({
                'name': run['name'],
                'budget': run['budget'],
                'spent': run['spent'],
                'status': run['status'],
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', runId);
          await db.update(
            'cached_runs',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [runId],
          );
        }
      }

      // 5. Process pending updates to items
      final unsyncedItems = await db.query(
        'cached_items',
        where:
            'sync_status = "pending_update" OR sync_status = "pending_insert"',
      );
      for (var item in unsyncedItems) {
        final runId = item['run_id'] as String;
        if (!isTempId(runId)) {
          final existingRemote = await _client!
              .from('grocery_run_items')
              .select()
              .eq('run_id', runId)
              .eq('commodity', item['commodity']!)
              .maybeSingle();

          if (existingRemote != null) {
            await _client!
                .from('grocery_run_items')
                .update({
                  'quantity': item['quantity'],
                  'checked': item['checked'] == 1,
                })
                .eq('id', existingRemote['id']);

            await db.update(
              'cached_items',
              {
                'id': existingRemote['id'] as String,
                'sync_status': 'synced',
              },
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          } else {
            final newRemote = await _client!.from('grocery_run_items').insert({
              'run_id': runId,
              'commodity': item['commodity'],
              'price': item['price'],
              'quantity': item['quantity'],
              'unit': item['unit'],
              'category': item['category'],
              'market': item['market'],
              'checked': item['checked'] == 1,
            }).select().single();

            await db.update(
              'cached_items',
              {
                'id': newRemote['id'] as String,
                'sync_status': 'synced',
              },
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          }
        }
      }

      notifyListeners();
    } catch (e, stack) {
      TelemetryService.instance.logError(e, stack, "background sync worker");
    }
  }
}
