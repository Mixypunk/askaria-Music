import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _anim;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D0D), Color(0xFF0F0A1E), Color(0xFF0D0D0D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.4, 1],
          ),
        ),
        child: SafeArea(child: FadeTransition(
          opacity: _fadeIn,
          child: Column(children: [
            const SizedBox(height: 52),

            // ── Logo avec glow ─────────────────────────────────────
            Center(
              child: Stack(alignment: Alignment.center, children: [
                // Halo gradient
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Sp.g2.withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Image.network(
                  'https://askaria-music.duckdns.org/static/logo.webp',
                  width: 100,
                  errorBuilder: (_, __, ___) => ShaderMask(
                    shaderCallback: (b) => kGradV.createShader(b),
                    child: const Icon(Icons.music_note_rounded,
                        size: 80, color: Colors.white),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),
            const Text('Bienvenue sur Askaria',
              textAlign: TextAlign.center,
              style: TextStyle(color: Sp.white, fontSize: 26,
                  fontWeight: FontWeight.bold, height: 1.2)),
            const SizedBox(height: 8),
            const Text('Votre musique. Partout, chez vous.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Sp.white70, fontSize: 15)),
            const SizedBox(height: 36),

            // ── Pill switcher tabs ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Sp.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Sp.white12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  _TabPill(0, Icons.qr_code_scanner_rounded, 'QR Code',
                      _tab, (i) => setState(() => _tab = i)),
                  _TabPill(1, Icons.keyboard_rounded, 'Connexion',
                      _tab, (i) => setState(() => _tab = i)),
                ]),
              ),
            ),
            const SizedBox(height: 28),

            Expanded(child: _tab == 0 ? const _QrTab() : const _ManualTab()),
          ]),
        )),
      ),
    );
  }
}

// ── Pill tab widget ────────────────────────────────────────────────────────────
class _TabPill extends StatelessWidget {
  final int idx;
  final IconData icon;
  final String label;
  final int current;
  final ValueChanged<int> onTap;
  const _TabPill(this.idx, this.icon, this.label, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = current == idx;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: sel ? kGrad : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: sel ? [BoxShadow(
            color: Sp.g2.withOpacity(0.3), blurRadius: 10,
            offset: const Offset(0, 2))] : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: sel ? Colors.white : Sp.white70),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: sel ? Colors.white : Sp.white70,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            fontSize: 13)),
        ]),
      ),
    ));
  }
}

// ── QR Tab ────────────────────────────────────────────────────────────────────
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
      const Text(
        'Paramètres → Appairer un appareil sur Askaria',
        textAlign: TextAlign.center,
        style: TextStyle(color: Sp.white70, fontSize: 13)),
      const SizedBox(height: 16),
      Expanded(child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: kGradV,
          boxShadow: [BoxShadow(
            color: Sp.g2.withOpacity(0.3), blurRadius: 20,
            offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: _loading
              ? Container(
                  color: Sp.card,
                  child: const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Sp.g2, strokeWidth: 2),
                      SizedBox(height: 16),
                      Text('Connexion...', style: TextStyle(color: Sp.white70)),
                    ])))
              : MobileScanner(onDetect: _onDetect)),
      )),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
          ),
          child: Text(_error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ),
      ],
    ]),
  );
}

// ── Manual Tab ────────────────────────────────────────────────────────────────
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

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

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
      // Email/nom
      _GlassField(
        controller: _u,
        hint: 'Email ou nom d\'utilisateur',
        icon: Icons.alternate_email_rounded,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      // Mot de passe
      _GlassField(
        controller: _p,
        hint: 'Mot de passe',
        icon: Icons.lock_outline_rounded,
        obscureText: _obs,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _login(),
        suffix: IconButton(
          icon: Icon(
            _obs ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: Sp.white70, size: 20),
          onPressed: () => setState(() => _obs = !_obs)),
      ),
      if (_err != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Text(_err!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity,
        child: GBtn('Se connecter',
            onTap: _loading ? null : _login, loading: _loading)),
    ]),
  );
}

// ── Glass field ────────────────────────────────────────────────────────────────
class _GlassField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: 54,
    decoration: BoxDecoration(
      color: Sp.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: _focused ? Sp.g2.withOpacity(0.6) : Sp.white12,
        width: _focused ? 1.5 : 0.8,
      ),
    ),
    child: Row(children: [
      const SizedBox(width: 4),
      Icon(widget.icon,
        color: _focused ? Sp.g2 : Sp.white70, size: 20),
      const SizedBox(width: 4),
      Expanded(child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        textInputAction: widget.textInputAction,
        keyboardType: widget.keyboardType,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(color: Sp.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Sp.white40),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16)),
      )),
      if (widget.suffix != null) widget.suffix!,
    ]),
  );
}
