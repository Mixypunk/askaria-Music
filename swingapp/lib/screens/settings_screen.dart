import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/color_service.dart';
import '../widgets/artwork_widget.dart';

import '../providers/player_provider.dart';
import 'package:provider/provider.dart';
import 'stats_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  String _version = '';
  bool _saved = false;
  bool _notificationsEnabled = true;
  String _audioQuality = 'high'; // low / medium / high
  int _cacheSize = 0; // en Mo

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = SwingApiService().baseUrl;
    _loadPrefs();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => _version = 'v${i.version}+${i.buildNumber}');
    });
    _calcCacheSize();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notif_enabled') ?? true;
      _audioQuality = prefs.getString('audio_quality') ?? 'high';
    });
  }

  Future<void> _calcCacheSize() async {
    // Estimer le cache d'images (nb d'entrées × taille moyenne ~50Ko)
    final size = _artCacheSize();
    if (mounted) setState(() => _cacheSize = size);
  }

  int _artCacheSize() {
    return artCache.count * 50;
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
          onPressed: () => Navigator.pop(ctx))),
      body: ListView(padding: const EdgeInsets.all(20), children: [

        // ── SERVEUR ──────────────────────────────────────────────
        _sectionTitle('SERVEUR'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
              color: Sp.card, borderRadius: BorderRadius.circular(4)),
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
        const SizedBox(height: 28),

        // ── AUDIO ────────────────────────────────────────────────
        _sectionTitle('AUDIO'),
        const SizedBox(height: 10),
        _card(Column(children: [
          // Volume global
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              const Icon(Icons.volume_up_rounded, color: Sp.white70, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('Volume',
                style: TextStyle(color: Sp.white, fontSize: 15))),
              Consumer<PlayerProvider>(
                builder: (_, p, __) => Text(
                  '${(p.volume * 100).round()}%',
                  style: const TextStyle(color: Sp.white70, fontSize: 13))),
            ])),
          Consumer<PlayerProvider>(builder: (_, player, __) =>
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Sp.g2,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Sp.g2.withOpacity(0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
              child: Slider(
                value: player.volume,
                onChanged: (v) => player.setVolume(v)),
            )),
          const Divider(color: Colors.white12, height: 1, indent: 16),
          // Qualité audio
          ListTile(
            leading: const Icon(Icons.high_quality_rounded, color: Sp.white70, size: 20),
            title: const Text('Qualité de streaming',
              style: TextStyle(color: Sp.white, fontSize: 15)),
            trailing: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _audioQuality,
              dropdownColor: Sp.card,
              style: const TextStyle(color: Sp.white, fontSize: 13),
              items: const [
                DropdownMenuItem(value: 'low',    child: Text('Économique')),
                DropdownMenuItem(value: 'medium', child: Text('Standard')),
                DropdownMenuItem(value: 'high',   child: Text('Haute qualité')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _audioQuality = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('audio_quality', v);
              },
            )),
          ),
        ])),
        const SizedBox(height: 28),

        // ── NOTIFICATIONS ────────────────────────────────────────
        _sectionTitle('NOTIFICATIONS'),
        const SizedBox(height: 10),
        _card(SwitchListTile(
          value: _notificationsEnabled,
          activeColor: Sp.g2,
          secondary: const Icon(Icons.notifications_rounded,
              color: Sp.white70, size: 20),
          title: const Text('Notifications de mise à jour',
            style: TextStyle(color: Sp.white, fontSize: 15)),
          subtitle: const Text('Être averti des nouvelles versions',
            style: TextStyle(color: Sp.white70, fontSize: 12)),
          onChanged: (v) async {
            setState(() => _notificationsEnabled = v);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('notif_enabled', v);
          },
        )),
        const SizedBox(height: 28),

        // ── MISES À JOUR ─────────────────────────────────────────
        _sectionTitle('MISES À JOUR'),
        const SizedBox(height: 10),
        _card(Column(children: [
          _tile('Version actuelle', _version, Icons.info_outline_rounded, null),
          const Divider(color: Colors.white12, height: 1, indent: 56),
          _tile('Vérifier maintenant', '', Icons.system_update_rounded, _checkUpdate),
        ])),
        const SizedBox(height: 28),

        // ── CACHE ────────────────────────────────────────────────
        _sectionTitle('CACHE'),
        const SizedBox(height: 10),
        _card(Column(children: [
          _tile(
            'Images en cache',
            _cacheSize > 0 ? '~${_cacheSize} Ko' : 'Vide',
            Icons.image_rounded, null),
          const Divider(color: Colors.white12, height: 1, indent: 56),
          _tile('Vider le cache', '', Icons.delete_outline_rounded, _clearCache),
        ])),
        const SizedBox(height: 28),

        // ── STATISTIQUES ─────────────────────────────────────────
        _sectionTitle('STATISTIQUES'),
        const SizedBox(height: 10),
        _card(_tile('Mes statistiques d'écoute', '',
            Icons.bar_chart_rounded,
            () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const StatsScreen())))),
        const SizedBox(height: 28),

        // ── COMPTE ───────────────────────────────────────────────
        _sectionTitle('COMPTE'),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _logout,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(4)),
            child: const Center(child: Text('Se déconnecter',
              style: TextStyle(color: Colors.redAccent,
                  fontWeight: FontWeight.bold, fontSize: 15))))),

        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(
    color: Sp.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600));

  Widget _card(Widget child) => Container(
    decoration: BoxDecoration(color: Sp.card, borderRadius: BorderRadius.circular(8)),
    child: child);

  Widget _tile(String title, String sub, IconData icon, VoidCallback? onTap) =>
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: Sp.white70, size: 20),
      title: Text(title, style: const TextStyle(color: Sp.white, fontSize: 15)),
      subtitle: sub.isEmpty ? null
          : Text(sub, style: const TextStyle(color: Sp.white70, fontSize: 12)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: Sp.white70) : null,
      onTap: onTap);

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
    if (info != null) {
      await UpdateDialog.show(context, info);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vous utilisez déjà la dernière version !'),
        backgroundColor: Sp.card));
    }
  }

  Future<void> _clearCache() async {
    ColorService.clearCache();
    artCache.clear();
    setState(() => _cacheSize = 0);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Cache vidé !'),
      backgroundColor: Sp.card,
      behavior: SnackBarBehavior.floating));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        title: const Text('Se déconnecter ?',
          style: TextStyle(color: Colors.white)),
        content: const Text('Vous devrez vous reconnecter.',
          style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
              style: TextStyle(color: Colors.white70))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter',
              style: TextStyle(color: Colors.redAccent))),
        ]));
    if (confirm == true && mounted) {
      await SwingApiService().logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }
}
