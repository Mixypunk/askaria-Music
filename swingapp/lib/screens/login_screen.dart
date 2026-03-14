import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D14), Color(0xFF1A1030), Color(0xFF0D0D14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 48),
            // Logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: kGradient,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppColors.grad2.withOpacity(0.5),
                  blurRadius: 30, spreadRadius: 5,
                )],
              ),
              child: const Icon(Icons.music_note_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            GradientText('SwingApp',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
            const SizedBox(height: 6),
            const Text('Votre musique, partout',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 36),

            // Tab switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(children: [
                _tabBtn('QR Code', Icons.qr_code_scanner_rounded, 0),
                _tabBtn('Manuel', Icons.keyboard_rounded, 1),
              ]),
            ),
            const SizedBox(height: 28),

            Expanded(child: _tab == 0 ? const _QrTab() : const _ManualTab()),
          ]),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, IconData icon, int idx) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active ? kGradient : null,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: active ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
          ]),
        ),
      ),
    );
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning || _loading) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;
    setState(() { _scanning = false; _loading = true; _error = null; });
    final parts = raw.trim().split(' ');
    if (parts.length < 2) {
      setState(() { _loading = false; _error = 'QR code invalide'; _scanning = true; });
      return;
    }
    final ok = await SwingApiService().pairWithCode(parts[0], parts[1]);
    if (!mounted) return;
    if (ok) Navigator.of(context).pushReplacementNamed('/home');
    else setState(() { _loading = false; _error = 'Échec — essaie la connexion manuelle'; _scanning = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(children: [
        Text('Settings → Pair device sur Swing Music (PC)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: kGradient,
              boxShadow: [BoxShadow(color: AppColors.grad2.withOpacity(0.3), blurRadius: 20)],
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: _loading
                  ? Container(color: AppColors.card,
                      child: const Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.grad2),
                          SizedBox(height: 16),
                          Text('Connexion en cours...', style: TextStyle(color: Colors.white)),
                        ],
                      )))
                  : MobileScanner(onDetect: _onDetect),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
          ),
        ],
      ]),
    );
  }
}

class _ManualTab extends StatefulWidget {
  const _ManualTab();
  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Remplis tous les champs');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await SwingApiService().login(_userCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) Navigator.of(context).pushReplacementNamed('/home');
    else setState(() { _loading = false; _error = 'Identifiants incorrects'; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(children: [
        // Username
        TextField(
          controller: _userCtrl,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nom d\'utilisateur',
            prefixIcon: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            filled: true, fillColor: AppColors.card,
          ),
        ),
        const SizedBox(height: 14),
        // Password
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: AppColors.textSecondary),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            filled: true, fillColor: AppColors.card,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: GradientButton(label: 'Se connecter', onPressed: _loading ? null : _login, loading: _loading),
        ),
      ]),
    );
  }
}
