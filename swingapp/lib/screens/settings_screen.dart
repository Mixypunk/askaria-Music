import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  String _version = '';
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = SwingApiService().baseUrl;
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = 'v${i.version}');
    });
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Paramètres'),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(ctx)),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // Section serveur
        const Text('SERVEUR', style: TextStyle(
          color: Sp.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Sp.card, borderRadius: BorderRadius.circular(4)),
          child: TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: Sp.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'https://mon-serveur.duckdns.org',
              hintStyle: TextStyle(color: Sp.white70),
              prefixIcon: Icon(Icons.dns_rounded, color: Sp.white70, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity,
          child: GBtn(_saved ? '✓ Sauvegardé' : 'Enregistrer', onTap: _save)),
        const SizedBox(height: 32),

        // Section mise à jour
        const Text('MISES À JOUR', style: TextStyle(
          color: Sp.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _tile('Version actuelle', _version, Icons.info_outline_rounded, null),
        _tile('Vérifier les mises à jour', '', Icons.system_update_rounded, _checkUpdate),
        const SizedBox(height: 32),

        // Déconnexion
        const Text('COMPTE', style: TextStyle(
          color: Sp.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            await SwingApiService().logout();
            if (mounted) Navigator.of(ctx).pushReplacementNamed('/login');
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(4)),
            child: const Center(child: Text('Se déconnecter',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15))),
          ),
        ),
      ]),
    );
  }

  Widget _tile(String title, String sub, IconData icon, VoidCallback? onTap) =>
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Icon(icon, color: Sp.white70),
      title: Text(title, style: const TextStyle(color: Sp.white, fontSize: 15)),
      subtitle: sub.isEmpty ? null : Text(sub, style: const TextStyle(color: Sp.white70)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: Sp.white70)
          : null,
      onTap: onTap,
    );

  Future<void> _save() async {
    await SwingApiService().saveUrl(_urlCtrl.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService().checkForUpdate();
    if (!mounted) return;
    if (info != null) await UpdateDialog.show(context, info);
    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Vous utilisez déjà la dernière version !'),
      backgroundColor: Sp.card));
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }
}
