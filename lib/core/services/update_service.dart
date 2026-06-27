import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final String githubUser;
  final String githubRepo;

  UpdateService({required this.githubUser, required this.githubRepo});

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse('https://api.github.com/repos/$githubUser/$githubRepo/releases/latest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
        if (_isVersionNewer(currentVersion, latestVersion)) {
          return UpdateInfo(
            latestVersion: latestVersion,
            downloadUrl: _getDownloadUrl(data),
            releaseNotes: data['body'],
          );
        }
      }
    } catch (e) {
      // Log error
    }
    return null;
  }

  bool _isVersionNewer(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length || latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }
    return false;
  }

  String _getDownloadUrl(Map<String, dynamic> data) {
    final assets = data['assets'] as List;
    if (Platform.isWindows) {
      final exe = assets.firstWhere((a) => a['name'].endsWith('.exe'), orElse: () => null);
      return exe != null ? exe['browser_download_url'] : data['html_url'];
    } else if (Platform.isAndroid) {
      final apk = assets.firstWhere((a) => a['name'].endsWith('.apk'), orElse: () => null);
      return apk != null ? apk['browser_download_url'] : data['html_url'];
    }
    return data['html_url'];
  }

  Future<void> launchUpdate(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;

  UpdateInfo({required this.latestVersion, required this.downloadUrl, this.releaseNotes});
}
