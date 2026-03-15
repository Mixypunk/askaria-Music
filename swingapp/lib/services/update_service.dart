import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner  = 'Mixypunk';
const _repo   = 'askaria-Music';
const _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

// Canal MethodChannel pour lancer l'installeur APK natif Android
const _installChannel = MethodChannel('com.mixypunk.askasound/install');

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

  // ── Vérification ───────────────────────────────────────────────────────
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

      if (resp.statusCode != 200) return null;
      final data = resp.data as Map<String, dynamic>;

      final tagName       = (data['tag_name'] as String? ?? '').trim();
      if (tagName.isEmpty) return null;
      final latestVersion = tagName.replaceFirst(RegExp(r'^v'), '');

      final info          = await PackageInfo.fromPlatform();
      final currentVersion = info.version.trim();

      debugPrint('Update: current=$currentVersion latest=$latestVersion');
      if (!_isNewer(latestVersion, currentVersion)) return null;

      // Version déjà ignorée ?
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('update_ignored_version') == latestVersion) return null;

      // Trouver l'APK
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }
      if (apkUrl == null || apkUrl.isEmpty) return null;

      return UpdateInfo(
        version:      latestVersion,
        tagName:      tagName,
        downloadUrl:  apkUrl,
        releaseNotes: data['body'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    }
  }

  bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('+').first.split('.').map(int.parse).toList();
      final c = current.split('+').first.split('.').map(int.parse).toList();
      while (l.length < 3) l.add(0);
      while (c.length < 3) c.add(0);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  // ── Téléchargement ─────────────────────────────────────────────────────
  Future<String> downloadApk(
    UpdateInfo info,
    ValueNotifier<double> progress,
  ) async {
    // Sauvegarder dans le répertoire de téléchargements externe
    // pour que FileProvider puisse y accéder
    final dir = await getExternalStorageDirectory()
        ?? await getTemporaryDirectory();
    final path = '${dir.path}/AskaSound-${info.version}.apk';

    final file = File(path);
    if (await file.exists()) await file.delete();

    final dio = Dio()
      ..options.receiveTimeout = const Duration(minutes: 10);

    await dio.download(
      info.downloadUrl,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) progress.value = received / total;
      },
    );

    debugPrint('APK téléchargé : $path (${await file.length()} bytes)');
    return path;
  }

  // ── Installation via Intent Android natif ─────────────────────────────
  Future<void> installApk(String apkPath) async {
    // Vérifier/demander la permission d'installer des sources inconnues
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          throw Exception(
            'Permission refusée. Activez "Sources inconnues" dans les paramètres Android.');
        }
      }
    }

    try {
      // Utiliser le MethodChannel pour lancer l'Intent natif avec FileProvider
      await _installChannel.invokeMethod('installApk', {'path': apkPath});
    } catch (e) {
      debugPrint('Install via channel failed: $e — fallback open_file');
      // Fallback : ouvrir directement
      throw Exception('Impossible de lancer l\'installeur : $e');
    }
  }

  // ── Once par session ───────────────────────────────────────────────────
  Future<UpdateInfo?> checkOnce() async {
    if (_checkedThisSession) return null;
    _checkedThisSession = true;
    return checkForUpdate();
  }

  Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('update_ignored_version', version);
  }
}

// ── Dialogue ──────────────────────────────────────────────────────────────────
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
  _Step _step = _Step.idle;
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
        const Expanded(child: Text('Mise à jour disponible',
          style: TextStyle(color: Colors.white, fontSize: 17))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Badge version
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Color(0xFF4776E6), Color(0xFF8E54E9), Color(0xFFD63AF9)]),
            borderRadius: BorderRadius.circular(20)),
          child: Text('Version ${widget.info.version}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),

        // Message selon l'étape
        if (_step == _Step.idle)
          const Text('Une nouvelle version est disponible.',
            style: TextStyle(color: Color(0xFF9D9DB8))),

        if (_step == _Step.downloading) ...[
          const Text('Téléchargement en cours...',
            style: TextStyle(color: Color(0xFF9D9DB8))),
          const SizedBox(height: 12),
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
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF8E54E9)),
                    minHeight: 6)),
                const SizedBox(height: 6),
                Text(v > 0 ? '${(v * 100).toStringAsFixed(0)}%' : '...',
                  style: const TextStyle(
                      color: Color(0xFF9D9DB8), fontSize: 12)),
              ])),
        ],

        if (_step == _Step.installing) ...[
          const Row(children: [
            SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: Color(0xFF8E54E9), strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Lancement de l\'installation...',
              style: TextStyle(color: Color(0xFF9D9DB8))),
          ]),
        ],

        if (_step == _Step.done) ...[
          const Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF1D9E75), size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Installation lancée — suivez les instructions Android.',
              style: TextStyle(color: Color(0xFF1D9E75), fontSize: 13))),
          ]),
        ],

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
            style: const TextStyle(
                color: Color(0xFFE24B4A), fontSize: 12)),
        ],
      ]),

      actions: [
        if (_step == _Step.idle) ...[
          TextButton(
            onPressed: () async {
              await UpdateService().ignoreVersion(widget.info.version);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Plus tard',
                style: TextStyle(color: Color(0xFF9D9DB8)))),
          _GradBtn('Mettre à jour', _startUpdate),
        ],
        if (_step == _Step.done)
          _GradBtn('Fermer', () => Navigator.pop(context)),
      ],
    );
  }

  Future<void> _startUpdate() async {
    setState(() { _step = _Step.downloading; _error = null; });
    try {
      final path = await UpdateService()
          .downloadApk(widget.info, _progress);

      if (mounted) setState(() => _step = _Step.installing);

      await UpdateService().installApk(path);

      if (mounted) setState(() => _step = _Step.done);
    } catch (e) {
      if (mounted) setState(() {
        _step = _Step.idle;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() { _progress.dispose(); super.dispose(); }
}

enum _Step { idle, downloading, installing, done }

class _GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradBtn(this.label, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [
          Color(0xFF4776E6), Color(0xFF8E54E9), Color(0xFFD63AF9)]),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold))),
  );
}
