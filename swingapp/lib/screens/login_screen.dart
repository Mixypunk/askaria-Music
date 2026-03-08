import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0; // 0 = QR, 1 = manuel

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Logo
            Icon(Icons.music_note_rounded,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('SwingApp',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 4),
            Text('askaria-music.duckdns.org',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
            const SizedBox(height: 24),

            // Tab switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('QR Code'), icon: Icon(Icons.qr_code_scanner_rounded)),
                  ButtonSegment(value: 1, label: Text('Manuel'), icon: Icon(Icons.keyboard_rounded)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _tab == 0
                  ? const _QrTab()
                  : const _ManualTab(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── QR SCANNER TAB ────────────────────────────────────────────────────────────
class _QrTab extends StatefulWidget {
  const _QrTab();

  @override
  State<_QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<_QrTab> {
  bool _scanning = true;
  bool _loading = false;
  String? _error;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning || _loading) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    setState(() { _scanning = false; _loading = true; _error = null; });

    // Format attendu: "https://askaria-music.duckdns.org eT_mog"
    final parts = raw.trim().split(' ');
    if (parts.length < 2) {
      setState(() {
        _loading = false;
        _error = 'QR code invalide';
        _scanning = true;
      });
      return;
    }

    final serverUrl = parts[0];
    final code = parts[1];

    final ok = await SwingApiService().pairWithCode(serverUrl, code);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _loading = false;
        _error = 'Échec du pairing — essaie la connexion manuelle';
        _scanning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Sur Swing Music (PC) :\nSettings → Pair device → Scanne le QR',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _loading
                  ? Container(
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text('Connexion...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    )
                  : MobileScanner(
                      onDetect: _onDetect,
                      overlayBuilder: (context, constraints) => Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── MANUEL TAB ────────────────────────────────────────────────────────────────
class _ManualTab extends StatefulWidget {
  const _ManualTab();

  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Remplis tous les champs');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final ok = await SwingApiService().login(
      _userCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _loading = false;
        _error = 'Username ou mot de passe incorrect';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          TextField(
            controller: _userCtrl,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nom d\'utilisateur',
              prefixIcon: const Icon(Icons.person_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Se connecter', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
