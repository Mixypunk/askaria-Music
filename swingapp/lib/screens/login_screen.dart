import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Sp.bg,
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 56),
        // Logo Spotify style
        ShaderMask(
          shaderCallback: (b) => kGradV.createShader(b),
          child: const Icon(Icons.music_note_rounded, size: 80, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text('Votre musique.\nPartout, chez vous.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Sp.white, fontSize: 24,
              fontWeight: FontWeight.bold, height: 1.3)),
        const SizedBox(height: 8),
        const Text('Votre musique personnelle, partout.',
          style: TextStyle(color: Sp.white70, fontSize: 14)),
        const SizedBox(height: 40),

        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: Sp.card, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              _tab_(0, Icons.qr_code_scanner_rounded, 'QR Code'),
              _tab_(1, Icons.keyboard_rounded, 'Connexion'),
            ]),
          ),
        ),
        const SizedBox(height: 32),

        Expanded(child: _tab == 0 ? const _QrTab() : const _ManualTab()),
      ])),
    );
  }

  Widget _tab_(int idx, IconData icon, String label) {
    final sel = _tab == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: sel ? kGrad : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: sel ? Colors.white : Sp.white70),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: sel ? Colors.white : Sp.white70,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ]),
      ),
    ));
  }
}

class _QrTab extends StatefulWidget {
  const _QrTab();
  @override
  State<_QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<_QrTab> {
  bool _scanning = true, _loading = false;
  String? _error;

  Future<void> _onDetect(BarcodeCapture c) async {
    if (!_scanning || _loading) return;
    final raw = c.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    setState(() { _scanning = false; _loading = true; _error = null; });

    // Format attendu: "{serverUrl} {code}"
    // Robuste : on cherche le dernier espace comme separateur
    final trimmed = raw.trim();
    final lastSpace = trimmed.lastIndexOf(' ');
    if (lastSpace <= 0) {
      setState(() { _loading = false; _error = 'QR invalide — format inconnu'; _scanning = true; });
      return;
    }
    final serverUrl = trimmed.substring(0, lastSpace);
    final code      = trimmed.substring(lastSpace + 1);

    if (serverUrl.isEmpty || code.isEmpty) {
      setState(() { _loading = false; _error = 'QR invalide — données manquantes'; _scanning = true; });
      return;
    }

    final ok = await SwingApiService().pairWithCode(serverUrl, code);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/root');
    } else {
      setState(() { _loading = false; _error = 'Échec du pairing — vérifiez le serveur'; _scanning = true; });
    }
  }

  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(children: [
      Text('Paramètres → Appairer un appareil sur Askaria',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Sp.white70, fontSize: 13)),
      const SizedBox(height: 16),
      Expanded(child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: kGradV,
        ),
        padding: const EdgeInsets.all(3),
        child: ClipRRect(borderRadius: BorderRadius.circular(9),
          child: _loading
              ? Container(color: Sp.card, child: const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Sp.g2),
                    SizedBox(height: 16),
                    Text('Connexion...', style: TextStyle(color: Sp.white)),
                  ])))
              : MobileScanner(onDetect: _onDetect)),
      )),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
      ],
    ]),
  );
}

class _ManualTab extends StatefulWidget {
  const _ManualTab();
  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _loading = false, _obs = true;
  String? _err;

  Future<void> _login() async {
    if (_u.text.trim().isEmpty || _p.text.isEmpty) {
      setState(() => _err = 'Remplis tous les champs'); return;
    }
    setState(() { _loading = true; _err = null; });
    final ok = await SwingApiService().login(_u.text.trim(), _p.text);
    if (!mounted) return;
    if (ok) Navigator.of(context).pushReplacementNamed('/root');
    else setState(() { _loading = false; _err = 'Identifiants incorrects'; });
  }

  @override
  Widget build(BuildContext ctx) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(children: [
      // Username
      Container(
        height: 52,
        decoration: BoxDecoration(color: Sp.card, borderRadius: BorderRadius.circular(4)),
        child: TextField(
          controller: _u, textInputAction: TextInputAction.next,
          style: const TextStyle(color: Sp.white, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Nom d\'utilisateur', hintStyle: TextStyle(color: Sp.white70),
            prefixIcon: Icon(Icons.person_outline_rounded, color: Sp.white70, size: 20),
            border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
      const SizedBox(height: 12),
      // Password
      Container(
        height: 52,
        decoration: BoxDecoration(color: Sp.card, borderRadius: BorderRadius.circular(4)),
        child: TextField(
          controller: _p, obscureText: _obs,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          style: const TextStyle(color: Sp.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Mot de passe', hintStyle: const TextStyle(color: Sp.white70),
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Sp.white70, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obs ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Sp.white70, size: 20),
              onPressed: () => setState(() => _obs = !_obs)),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
      if (_err != null) ...[
        const SizedBox(height: 12),
        Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity,
        child: GBtn('Se connecter', onTap: _loading ? null : _login, loading: _loading)),
    ]),
  );
}
