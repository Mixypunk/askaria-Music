import 'package:flutter/material.dart';
import '../main.dart';
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
  void initState() { super.initState(); _urlCtrl.text = SwingApiService().baseUrl; }

  void _save() async {
    await SwingApiService().saveUrl(_urlCtrl.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Serveur', style: TextStyle(
            color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(
          controller: _urlCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'https://mon-serveur.duckdns.org',
            filled: true, fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: _saved ? '✓ Sauvegardé' : 'Sauvegarder',
          onPressed: _save,
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () async {
            await SwingApiService().logout();
            if (mounted) Navigator.of(context).pushReplacementNamed('/login');
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Center(child: Text('Déconnexion',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }
}
