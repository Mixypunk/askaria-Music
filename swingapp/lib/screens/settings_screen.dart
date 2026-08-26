import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/theme_notifier.dart';
import '../services/network_quality_service.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/color_service.dart';
import '../widgets/artwork_widget.dart';

import '../providers/player_provider.dart';
import 'package:provider/provider.dart';
import 'stats_screen.dart';
import 'eq_screen.dart';
import 'downloads_screen.dart';
import 'profile_screen.dart';
import 'tv_pair_screen.dart';

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
  String _audioQuality = 'high';
  bool _autoQuality = false;
  int _cacheSize = 0;

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
      _autoQuality  = NetworkQualityService.instance.autoQuality;
    });
  }

  Future<void> _calcCacheSize() async {
    final size = _artCacheSize();
    if (mounted) setState(() => _cacheSize = size);
  }

  int _artCacheSize() => artCache.count * 50;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Paramètres',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.pop(ctx))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [

          // ── SERVEUR ──────────────────────────────────────────────
          _SectionTitle('Serveur', Icons.dns_rounded),
          _SettingsCard(children: [
            Container(
              decoration: BoxDecoration(
                  color: Sp.surface, borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: _urlCtrl,
                style: const TextStyle(color: Sp.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'https://mon-serveur.duckdns.org',
                  hintStyle: TextStyle(color: Sp.white40),
                  prefixIcon: Icon(Icons.link_rounded, color: Sp.white70, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: GBtn(_saved ? '✓ Sauvegardé' : 'Enregistrer',
                  onTap: _save)),
          ]),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.tv_rounded,
              iconColor: const Color(0xFF4776E6),
              title: 'Connecter la TV',
              subtitle: 'Appairer via un code 6 chiffres',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const TvPairScreen())),
            ),
          ]),
          const SizedBox(height: 24),

          // ── APPARENCE ────────────────────────────────────────────
          _SectionTitle('Apparence', Icons.palette_rounded),
          _SettingsCard(children: [
            Consumer<ThemeNotifier>(
              builder: (_, theme, __) => _SettingsTileDropdown<ThemeMode>(
                icon: Icons.dark_mode_rounded,
                iconColor: const Color(0xFF8E54E9),
                title: 'Thème',
                value: theme.mode,
                items: const [
                  DropdownMenuItem(value: ThemeMode.dark,   child: Text('Sombre')),
                  DropdownMenuItem(value: ThemeMode.light,  child: Text('Clair')),
                  DropdownMenuItem(value: ThemeMode.system, child: Text('Système')),
                ],
                onChanged: (v) { if (v != null) theme.setMode(v); },
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // ── AUDIO ────────────────────────────────────────────────
          _SectionTitle('Audio', Icons.equalizer_rounded),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.equalizer_rounded,
              iconColor: const Color(0xFF8E54E9),
              title: 'Égaliseur (EQ)',
              subtitle: 'Presets : Rock, Jazz, Bass Boost…',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const EqScreen())),
            ),
            _Divider(),
            // Volume
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF509BF5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.volume_up_rounded,
                      color: Color(0xFF509BF5), size: 18)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Volume',
                  style: TextStyle(color: Sp.white, fontSize: 15))),
                Consumer<PlayerProvider>(
                  builder: (_, p, __) => Text(
                    '${(p.volume * 100).round()}%',
                    style: const TextStyle(color: Sp.white70, fontSize: 13))),
              ])),
            Consumer<PlayerProvider>(builder: (_, player, __) =>
              _GradientSlider(
                value: player.volume,
                onChanged: (v) => player.setVolume(v))),
            _Divider(),
            // Qualité auto
            _SettingsTileSwitch(
              icon: Icons.network_check_rounded,
              iconColor: const Color(0xFF148A08),
              title: 'Qualité auto (réseau)',
              subtitle: 'WiFi → max, 4G → standard, 2G → éco',
              value: _autoQuality,
              onChanged: (v) async {
                setState(() => _autoQuality = v);
                await NetworkQualityService.instance.setAutoQuality(v);
              },
            ),
            _Divider(),
            // Qualité streaming
            _SettingsTileDropdown<String>(
              icon: Icons.high_quality_rounded,
              iconColor: const Color(0xFF4776E6),
              title: 'Qualité de streaming',
              value: _audioQuality,
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
            ),
            _Divider(),
            // Crossfade
            Consumer<PlayerProvider>(builder: (_, player, __) => Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBA5D07).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: Color(0xFFBA5D07), size: 18)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Crossfade',
                    style: TextStyle(color: Sp.white, fontSize: 15))),
                  Text(
                    player.crossfadeSeconds == 0
                        ? 'Désactivé'
                        : '${player.crossfadeSeconds}s',
                    style: const TextStyle(color: Sp.white70, fontSize: 13)),
                ])),
              _GradientSlider(
                value: player.crossfadeSeconds.toDouble(),
                min: 0, max: 12, divisions: 12,
                onChanged: (v) => player.setCrossfade(v.round())),
            ])),
          ]),
          const SizedBox(height: 24),

          // ── NOTIFICATIONS ────────────────────────────────────────
          _SectionTitle('Notifications', Icons.notifications_rounded),
          _SettingsCard(children: [
            _SettingsTileSwitch(
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFFE8115B),
              title: 'Notifications de mise à jour',
              subtitle: 'Être averti des nouvelles versions',
              value: _notificationsEnabled,
              onChanged: (v) async {
                setState(() => _notificationsEnabled = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notif_enabled', v);
              },
            ),
          ]),
          const SizedBox(height: 24),

          // ── MISES À JOUR ─────────────────────────────────────────
          _SectionTitle('Mises à jour', Icons.system_update_rounded),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconColor: Sp.white40,
              title: 'Version actuelle',
              subtitle: _version,
            ),
            _Divider(),
            _SettingsTile(
              icon: Icons.system_update_rounded,
              iconColor: const Color(0xFF4776E6),
              title: 'Vérifier maintenant',
              onTap: _checkUpdate,
            ),
          ]),
          const SizedBox(height: 24),

          // ── CACHE ────────────────────────────────────────────────
          _SectionTitle('Cache', Icons.storage_rounded),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.image_rounded,
              iconColor: Sp.white40,
              title: 'Images en cache',
              subtitle: _cacheSize > 0 ? '~$_cacheSize Ko' : 'Vide',
            ),
            _Divider(),
            _SettingsTile(
              icon: Icons.delete_outline_rounded,
              iconColor: Colors.redAccent,
              title: 'Vider le cache',
              onTap: _clearCache,
            ),
          ]),
          const SizedBox(height: 24),

          // ── STATISTIQUES ─────────────────────────────────────────
          _SectionTitle('Statistiques', Icons.bar_chart_rounded),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFF8E54E9),
              title: 'Mes statistiques d\'écoute',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const StatsScreen())),
            ),
          ]),
          const SizedBox(height: 24),

          // ── HORS-LIGNE ───────────────────────────────────────────
          _SectionTitle('Hors-ligne', Icons.download_rounded),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.download_done_rounded,
              iconColor: const Color(0xFF148A08),
              title: 'Téléchargements',
              subtitle: 'Gérer les titres hors-ligne',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const DownloadsScreen())),
            ),
          ]),
          const SizedBox(height: 24),

          // ── PROFIL ───────────────────────────────────────────────
          _SectionTitle('Mon profil', Icons.manage_accounts_rounded),
          _SettingsCard(children: [
            _SettingsTile(
              icon: Icons.manage_accounts_rounded,
              iconColor: const Color(0xFF4776E6),
              title: 'Modifier mon profil',
              subtitle: 'Photo, nom, email, bio',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ProfileScreen())),
            ),
          ]),
          const SizedBox(height: 24),

          // ── COMPTE ───────────────────────────────────────────────
          _SectionTitle('Compte', Icons.logout_rounded),
          GestureDetector(
            onTap: _logout,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4))),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Se déconnecter',
                    style: TextStyle(color: Colors.redAccent,
                        fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ))),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helpers actions ──────────────────────────────────────────────────────────
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Vous utilisez déjà la dernière version !'),
        backgroundColor: Sp.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    }
  }

  Future<void> _clearCache() async {
    ColorService.clearCache();
    artCache.clear();
    setState(() => _cacheSize = 0);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Cache vidé !'),
      backgroundColor: Sp.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Sp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Se déconnecter ?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Vous devrez vous reconnecter.',
          style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
              style: TextStyle(color: Colors.white70))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter',
              style: TextStyle(color: Colors.redAccent,
                  fontWeight: FontWeight.bold))),
        ]));
    if (confirm == true && mounted) {
      await SwingApiService().logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }
}

// ── Composants UI ──────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Row(children: [
      Icon(icon, size: 14, color: Sp.white40),
      const SizedBox(width: 6),
      Text(title.toUpperCase(), style: const TextStyle(
        color: Sp.white40, fontSize: 11,
        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: kCardDecoration(radius: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
    color: Color(0x1AFFFFFF), height: 1, indent: 56);
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    leading: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: iconColor, size: 18)),
    title: Text(title, style: const TextStyle(
        color: Sp.white, fontSize: 15)),
    subtitle: subtitle != null && subtitle!.isNotEmpty
        ? Text(subtitle!,
            style: const TextStyle(color: Sp.white70, fontSize: 12))
        : null,
    trailing: onTap != null
        ? const Icon(Icons.chevron_right_rounded, color: Sp.white40, size: 20)
        : null,
    onTap: onTap,
  );
}

class _SettingsTileSwitch extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsTileSwitch({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    secondary: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: iconColor, size: 18)),
    title: Text(title, style: const TextStyle(color: Sp.white, fontSize: 15)),
    subtitle: subtitle != null
        ? Text(subtitle!,
            style: const TextStyle(color: Sp.white40, fontSize: 11))
        : null,
    value: value,
    activeColor: Sp.g2,
    onChanged: onChanged,
  );
}

class _SettingsTileDropdown<T> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _SettingsTileDropdown({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    leading: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: iconColor, size: 18)),
    title: Text(title, style: const TextStyle(color: Sp.white, fontSize: 15)),
    trailing: DropdownButtonHideUnderline(child: DropdownButton<T>(
      value: value,
      dropdownColor: Sp.card,
      borderRadius: BorderRadius.circular(12),
      style: const TextStyle(color: Sp.white, fontSize: 13),
      items: items,
      onChanged: onChanged,
    )),
  );
}

class _GradientSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  const _GradientSlider({
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderThemeData(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      activeTrackColor: Sp.g2,
      inactiveTrackColor: Colors.white12,
      thumbColor: Colors.white,
      overlayColor: Sp.g2.withValues(alpha: 0.2),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
    child: Slider(
      value: value, min: min, max: max,
      divisions: divisions,
      onChanged: onChanged),
  );
}
