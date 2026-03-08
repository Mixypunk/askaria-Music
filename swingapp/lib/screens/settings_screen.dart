import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstLaunch;
  const SettingsScreen({super.key, this.isFirstLaunch = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _testing = false;
  String? _status;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    final api = SwingApiService();
    _urlController.text = api.baseUrl.isNotEmpty
        ? api.baseUrl
        : 'https://askaria-music.duckdns.org';
  }

  Future<void> _testAndSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() { _testing = true; _status = null; });

    await SwingApiService().saveSettings(url, token: _tokenController.text.trim().isEmpty ? null : _tokenController.text.trim());
    final ok = await SwingApiService().testConnection();

    setState(() {
      _testing = false;
      _success = ok;
      _status = ok ? '✅ Connexion réussie !' : '❌ Impossible de joindre le serveur.';
    });

    if (ok && widget.isFirstLaunch && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isFirstLaunch
          ? null
          : AppBar(title: const Text('Paramètres')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isFirstLaunch) ...[
                const SizedBox(height: 40),
                Icon(Icons.music_note_rounded,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('SwingApp',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 8),
                Text('Configure ton serveur Swing Music',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 40),
              ],
              Text('URL du serveur',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.x:1970  ou  https://ton-domaine.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.dns_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Text('Token d\'authentification (optionnel)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Token si ton serveur est protégé',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Swing Music tourne par défaut sur le port 1970.\nEx: http://192.168.1.100:1970',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _testing ? null : _testAndSave,
                  child: _testing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Tester & Sauvegarder', style: TextStyle(fontSize: 16)),
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _success
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_status!, style: TextStyle(
                    color: _success ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
