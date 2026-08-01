import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../config/update_config.dart';
import 'local_db_service.dart';

class DbUpdateService {
  static final DbUpdateService instance = DbUpdateService._init();
  
  DbUpdateService._init();

  // Get local version file path
  Future<File> get _localVersionFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File(join(directory.path, 'local_version.json'));
  }

  // Get current local version code (returns 0 if not exist/not initialized)
  Future<int> getLocalVersionCode() async {
    try {
      final file = await _localVersionFile;
      if (!await file.exists()) {
        return 0;
      }
      final contents = await file.readAsString();
      final data = jsonDecode(contents);
      return data['version'] as int? ?? 0;
    } catch (e) {
      debugPrint("Error reading local version: $e");
      return 0;
    }
  }

  // Save version code locally
  Future<void> _saveLocalVersion(int version, String releaseDate, int totalRecords) async {
    try {
      final file = await _localVersionFile;
      final data = {
        'version': version,
        'release_date': releaseDate,
        'total_records': totalRecords,
      };
      await file.writeAsString(jsonEncode(data));
      debugPrint("Saved local database version: $version");
    } catch (e) {
      debugPrint("Error saving local version: $e");
    }
  }

  // Check if a new version is available on the remote server
  Future<Map<String, dynamic>?> checkNewVersion() async {
    try {
      final response = await http.get(Uri.parse(UpdateConfig.versionUrl))
          .timeout(const Duration(seconds: 10));
          
      if (response.statusCode == 200) {
        final remoteData = jsonDecode(response.body);
        final remoteVersion = remoteData['version'] as int? ?? 0;
        final localVersion = await getLocalVersionCode();
        
        return {
          'is_available': remoteVersion > localVersion,
          'remote_version': remoteVersion,
          'local_version': localVersion,
          'release_date': remoteData['release_date'] ?? 'Unknown',
          'total_records': remoteData['total_records'] ?? 0,
        };
      }
    } catch (e) {
      debugPrint("Error checking version from server: $e");
    }
    return null;
  }

  // Download, unzip, and apply database update
  Future<bool> downloadAndApplyUpdate({
    required int version,
    required String releaseDate,
    required int totalRecords,
    void Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint("Downloading update from: ${UpdateConfig.databaseUrl}");
      
      // Fetch zipped database file
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(UpdateConfig.databaseUrl));
      final response = await client.send(request).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        debugPrint("Download failed: HTTP ${response.statusCode}");
        return false;
      }

      final contentLength = response.contentLength ?? 0;
      List<int> bytes = [];
      
      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0 && onProgress != null) {
          final progress = bytes.length / contentLength;
          onProgress(progress);
        }
      }

      debugPrint("Download complete! Size: ${bytes.length} bytes. Unzipping...");
      
      // Decompress zip in background isolate using compute to prevent blocking main UI thread
      final decompressedBytes = await compute(_decompressZipIsolate, bytes);

      if (decompressedBytes == null) {
        debugPrint("Error: Could not find database file inside the downloaded zip.");
        return false;
      }

      debugPrint("Decompressed DB size: ${decompressedBytes.length} bytes. Overwriting...");
      
      // Call local database service to safely replace the old DB file
      await LocalDbService.instance.overwriteDatabase(decompressedBytes);
      
      // Save new version info
      await _saveLocalVersion(version, releaseDate, totalRecords);
      
      return true;
    } catch (e) {
      debugPrint("Update failed: $e");
      return false;
    }
  }
}

// Top-level function for background isolate decompression
List<int>? _decompressZipIsolate(List<int> zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  for (var file in archive) {
    if (file.name.endsWith('.db') || file.name == 'tipi_data.db') {
      return file.content as List<int>;
    }
  }
  return null;
}
