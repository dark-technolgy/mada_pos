import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class CloudBackupService {
  final _client = Supabase.instance.client;

  Future<void> uploadBackup(File file) async {
    final fileName = p.basename(file.path);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.storage
        .from('backups')
        .upload('$userId/$fileName', file);
  }

  Future<List<FileObject>> listBackups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    return await _client.storage.from('backups').list(path: userId);
  }

  Future<void> downloadBackup(String fileName, File targetFile) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client.storage
        .from('backups')
        .download('$userId/$fileName');
    
    await targetFile.writeAsBytes(response);
  }
}
