import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner = 'Mixypunk';
const _repo  = 'askaria-Music';
const _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

class UpdateInfo {
  final String version;     // ex: "1.0.42"
  final String tagName;     // ex: "v1.0.42"
  final String downloadUrl; // URL de l'APK
  final String releaseNotes;
  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static final UpdateService _i = UpdateService._();
  factory UpdateService() => _i;
  UpdateService._();

  // Vérifie s'il y a une mise à jour disponible
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio();
      final resp = await dio.get(_apiUrl,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}));

      if (resp.statusCode != 200) return null;
      final data = resp.data as Map<String, dynamic>;

      // Extraire version depuis le tag (ex: "v1.0.42" → "1.0.42")
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceFirst('v', '');

      // Version actuelle de l'app
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (!_isNewer(latestVersion, currentVersion)) return null;

      // Trouver l'APK dans les assets
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      if (apkUrl == null) return null;

      return UpdateInfo(
        version: latestVersion,
        tagName: tagName,
        downloadUrl: apkUrl,
        releaseNotes: data['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  // Compare versions "1.0.42" > "1.0.15"
  bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      while (l.length < 3) l.add(0);
      while (c.length < 3) c.add(0);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  // Télécharge et installe l'APK
  Future<void> downloadAndInstall(
    UpdateInfo info,
    ValueNotifier<double> progress,
  ) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/SwingApp-update.apk';

    final dio = Dio();
    await dio.download(
      info.downloadUrl,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) progress.value = received / total;
      },
    );

    await OpenFile.open(path);
  }

  // Vérifie une fois par session max
  static bool _checked = false;
  Future<UpdateInfo?> checkOnce() async {
    if (_checked) return null;
    _checked = true;

    // Ne pas vérifier si déjà ignorée récemment (24h)
    final prefs = await SharedPreferences.getInstance();
    final lastIgnored = prefs.getInt('update_ignored_at') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastIgnored < 86400000) return null; // 24h

    return checkForUpdate();
  }

  Future<void> ignoreCurrentUpdate(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('update_ignored_version', version);
    await prefs.setInt('update_ignored_at', DateTime.now().millisecondsSinceEpoch);
  }
}

// ── Dialogue de mise à jour ───────────────────────────────────────────────────
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  static Future<void> show(BuildContext context, UpdateInfo info) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  final _progress = ValueNotifier<double>(0);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFF4776E6), Color(0xFF8E54E9), Color(0xFFD63AF9)],
          ).createShader(b),
          child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 10),
        const Text('Mise à jour disponible',
          style: TextStyle(color: Colors.white, fontSize: 17)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4776E6), Color(0xFF8E54E9), Color(0xFFD63AF9)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Version ${widget.info.version}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        const Text('Une nouvelle version est disponible.',
          style: TextStyle(color: Color(0xFF9D9DB8))),
        if (_downloading) ...[
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (_, v, __) => Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v > 0 ? v : null,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF8E54E9)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text('${(v * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF9D9DB8), fontSize: 12)),
            ]),
          ),
        ],
      ]),
      actions: _downloading ? [] : [
        TextButton(
          onPressed: () async {
            await UpdateService().ignoreCurrentUpdate(widget.info.version);
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Plus tard', style: TextStyle(color: Color(0xFF9D9DB8))),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4776E6), Color(0xFF8E54E9), Color(0xFFD63AF9)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextButton(
            onPressed: () async {
              setState(() => _downloading = true);
              try {
                await UpdateService().downloadAndInstall(widget.info, _progress);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                setState(() => _downloading = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e'),
                    backgroundColor: const Color(0xFF1E1E30)),
                );
              }
            },
            child: const Text('Installer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
