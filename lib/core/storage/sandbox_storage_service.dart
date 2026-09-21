import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final sandboxStorageServiceProvider = Provider((ref) => SandboxStorageService());

class SandboxStorageService {
  
  // Temporary staging area — before record ID is assigned
  Future<String> saveTempCapture(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final tempDir = Directory('${dir.path}/temp_captures');
    if (!await tempDir.exists()) await tempDir.create(recursive: true);
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/$timestamp.jpg';
    await File(path).writeAsBytes(bytes);
    return path;
  }
  
  // Called by Part 07 when record is finalized
  Future<String> promoteToRecord({
    required String tempPath,
    required String recordId,
    required String imageType, // 'raw' or 'calibrated'
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final recordDir = Directory('${dir.path}/records/$recordId');
    if (!await recordDir.exists()) await recordDir.create(recursive: true);
    
    final destPath = '${recordDir.path}/$imageType.jpg';
    await File(tempPath).copy(destPath);
    await File(tempPath).delete(); // remove temp
    return destPath;
  }
  
  // Cleanup abandoned temp captures (older than 1 hour)
  Future<void> cleanupStaleTempCaptures() async {
    final dir = await getApplicationDocumentsDirectory();
    final tempDir = Directory('${dir.path}/temp_captures');
    if (!await tempDir.exists()) return;
    
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await for (final file in tempDir.list()) {
      if (file is File) {
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoff)) await file.delete();
      }
    }
  }
}
