import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── À personnaliser selon votre dépôt GitHub ──────────────────────────────────
const _owner = 'Mixypunk';       // Votre nom d'utilisateur GitHub
const _repo  = 'askaria-Music';  // Le nom exact de votre dépôt
// ──────────────────────────────────────────────────────────────────────────────

const _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

class UpdateInfo {
  final String version;
  final String tagName;
  final String downloadUrl;
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

  static bool _checkedThisSession = false;

  // ── Vérification principale ─────────────────────────────────────────────
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio()
        ..options.connectTimeout = const Duration(seconds: 8)
        ..options.receiveTimeout = const Duration(seconds: 8);

      final resp = await dio.get(_apiUrl, options: Options(
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        validateStatus: (s) => s != null && s < 500,
      ));

      if (resp.statusCode != 200) {
        debugPrint('UpdateService: HTTP ${resp.statusCode}');
        return null;
      }

      final data = resp.data as Map<String, dynamic>;

      // Tag GitHub ex: "v1.0.42" → version "1.0.42"
      final tagName = (data['tag_name'] as String? ?? '').trim();
      if (tagName.isEmpty) return null;
      final latestVersion = tagName.replaceFirst(RegExp(r'^v'), '');

      // Version actuelle installée (depuis pubspec via PackageInfo)
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version.trim();

      debugPrint('UpdateService: current=$currentVersion latest=$latestVersion');

      if (!_isNewer(latestVersion, currentVersion)) {
        debugPrint('UpdateService: déjà à jour');
        return null;
      }

      // Vérifier si cette version a déjà été ignorée
      final prefs = await SharedPreferences.getInstance();
      final ignoredVersion = prefs.getString('update_ignored_version') ?? '';
      if (ignoredVersion == latestVersion) {
        debugPrint('UpdateService: version $latestVersion ignorée');
        return null;
      }

      // Trouver l'APK dans les assets de la release
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          debugPrint('UpdateService: APK trouvé → $apkUrl');
          break;
        }
      }

      if (apkUrl == null || apkUrl.isEmpty) {
        debugPrint('UpdateService: aucun APK dans la release');
        return null;
      }

      return UpdateInfo(
        version: latestVersion,
        tagName: tagName,
        downloadUrl: apkUrl,
        releaseNotes: data['body'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('UpdateService: erreur → $e');
      return null;
    }
  }

  // ── Compare "1.0.42" > "1.0.15" ────────────────────────────────────────
  bool _isNewer(String latest, String current) {
    try {
      // Ignorer le build number (+42) s'il est présent
      final l = latest.split('+').first.split('.').map(int.parse).toList();
      final c = current.split('+').first.split('.').map(int.parse).toList();
      while (l.length < 3) l.add(0);
      while (c.length < 3) c.add(0);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (e) {
      debugPrint('UpdateService: erreur comparaison version → $e');
    }
    return false;
  }

  // ── Téléchargement + installation ──────────────────────────────────────
  Future<void> downloadAndInstall(
    UpdateInfo info,
    ValueNotifier<double> progress,
  ) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/AskaSound-update-${info.version}.apk';

    // Supprimer un ancien fichier si présent
    final file = File(path);
    if (await file.exists()) await file.delete();

    final dio = Dio()
      ..options.receiveTimeout = const Duration(minutes: 5);

    await dio.download(
      info.downloadUrl,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) progress.value = received / total;
      },
    );

    debugPrint('UpdateService: APK téléchargé → $path');
    final result = await OpenFile.open(path);
    debugPrint('UpdateService: OpenFile result → ${result.message}');
  }

  // ── Vérification une seule fois par session ─────────────────────────────
  Future<UpdateInfo?> checkOnce() async {
    if (_checkedThisSession) return null;
    _checkedThisSession = true;
    return checkForUpdate();
  }

  Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('update_ignored_version', version);
    debugPrint('UpdateService: version $version ignorée');
  }
}

// ── Dialogue de mise à jour ────────────────────────────────────────────────────
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
  bool _done = false;
  String? _error;
  final _progress = ValueNotifier<double>(0);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.system_update_rounded,
            color: Color(0xFF8E54E9), size: 28),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Mise à jour disponible',
            style: TextStyle(color: Colors.white, fontSize: 17))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Badge version
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4776E6), Color(0xFF8E54E9), Color(0xFFD63AF9)]),
            borderRadius: BorderRadius.circular(20)),
          child: Text('Version ${widget.info.version}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        const Text('Une nouvelle version est disponible.',
          style: TextStyle(color: Color(0xFF9D9DB8))),

        // Barre de progression
        if (_downloading) ...[ 
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (_, v, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v > 0 ? v : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF8E54E9)),
                    minHeight: 6)),
                const SizedBox(height: 6),
                Text(
                  v > 0 ? '${(v * 100).toStringAsFixed(0)}%' : 'Téléchargement...',
                  style: const TextStyle(
                      color: Color(0xFF9D9DB8), fontSize: 12)),
              ]),
          ),
        ],

        // Erreur
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
            style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 12)),
        ],

        // Succès
        if (_done) ...[
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF1D9E75), size: 18),
            SizedBox(width: 6),
            Text('Prêt à installer !',
              style: TextStyle(color: Color(0xFF1D9E75))),
          ]),
        ],
      ]),

      actions: _downloading ? [] : [
        // Ignorer
        if (!_done) TextButton(
          onPressed: () async {
            await UpdateService().ignoreVersion(widget.info.version);
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Plus tard',
              style: TextStyle(color: Color(0xFF9D9DB8)))),

        // Installer
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4776E6), Color(0xFF8E54E9),
                       Color(0xFFD63AF9)]),
            borderRadius: BorderRadius.circular(20)),
          child: TextButton(
            onPressed: _done ? () => Navigator.pop(context) : _startDownload,
            child: Text(_done ? 'Fermer' : 'Installer',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _error = null; });
    try {
      await UpdateService().downloadAndInstall(widget.info, _progress);
      if (mounted) setState(() { _downloading = false; _done = true; });
    } catch (e) {
      if (mounted) setState(() {
        _downloading = false;
        _error = 'Erreur de téléchargement : $e';
      });
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }
}
