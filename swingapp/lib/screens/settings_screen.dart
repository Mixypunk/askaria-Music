import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = SwingApiService().baseUrl;
  }

  void _save() async {
    await SwingApiService().saveUrl(_urlCtrl.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  void _logout() async {
    await SwingApiService().logout();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Serveur Swing Music',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL du serveur',
              hintText: 'https://mon-serveur.duckdns.org',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check : Icons.save_rounded),
            label: Text(_saved ? 'Sauvegardé !' : 'Sauvegarder'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }
}
