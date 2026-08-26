import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart';
import '../services/api_service.dart';

/// Écran permettant au mobile de connecter une TV Askaria
/// via un code à 6 chiffres affiché sur la TV.
class TvPairScreen extends StatefulWidget {
  const TvPairScreen({super.key});
  @override
  State<TvPairScreen> createState() => _TvPairScreenState();
}

class _TvPairScreenState extends State<TvPairScreen>
    with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  late final TabController _tabCtrl;

  bool    _loading    = false;
  String? _error;
  String? _success;

  // Scanner QR
  bool _scannerActive = false;
  bool _scanned       = false;           // évite les doubles scans

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _error   = null;
        _success = null;
        _scanned = false;
        if (_tabCtrl.index == 1) {
          _scannerActive = true;
        } else {
          _scannerActive = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Soumission du code manuel ─────────────────────────────────────────────────
  Future<void> _submit() async {
    final raw = _codeCtrl.text.trim().replaceAll(' ', '');
    if (raw.length != 6) {
      setState(() => _error = 'Entrez les 6 chiffres affichés sur la TV.');
      return;
    }
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final msg = await SwingApiService().confirmTvPair(raw);
      if (mounted) {
        setState(() { _success = msg; _loading = false; });
        _codeCtrl.clear();
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  // ── Traitement d'un code scanné ───────────────────────────────────────────────
  Future<void> _onScan(String raw) async {
    if (_scanned || _loading) return;
    _scanned = true;

    // Le QR encode soit juste "482619", soit "482 619"
    final code = raw.trim().replaceAll(' ', '');
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() {
        _error   = 'QR non reconnu. Utilisez l\'onglet "Code manuel".';
        _scanned = false;
      });
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });
    try {
      final msg = await SwingApiService().confirmTvPair(code);
      if (mounted) {
        setState(() {
          _success       = msg;
          _loading       = false;
          _scannerActive = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
          _scanned = false;
        });
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Connecter la TV',
            style: TextStyle(
                color: Sp.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Sp.white, size: 20),
          onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // Onglets
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: Sp.card,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                gradient: kGrad,
                borderRadius: BorderRadius.circular(7),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Sp.white70,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.keyboard_rounded, size: 18),
                    text: 'Code manuel'),
                Tab(icon: Icon(Icons.qr_code_scanner_rounded, size: 18),
                    text: 'Scanner QR'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildManualTab(),
                _buildScannerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Onglet 1 : saisie manuelle ────────────────────────────────────────────────
  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // Icone TV
          Center(
            child: ShaderMask(
              shaderCallback: (b) => kGrad.createShader(b),
              child: const Icon(Icons.tv_rounded, size: 72, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Entrez le code affiché\nsur votre TV',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Sp.white, fontSize: 20, fontWeight: FontWeight.bold,
                height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'app TV → onglet "Via l\'app mobile"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Sp.white70, fontSize: 13),
          ),
          const SizedBox(height: 36),

          // Feedback erreur
          if (_error != null) ...[
            _FeedbackBanner(message: _error!, isError: true),
            const SizedBox(height: 16),
          ],

          // Feedback succès
          if (_success != null) ...[
            _FeedbackBanner(message: _success!, isError: false),
            const SizedBox(height: 16),
          ],

          // Champ de saisie du code
          Container(
            decoration: BoxDecoration(
                color: Sp.card, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _codeCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 7,        // 6 chiffres + espace au milieu
              inputFormatters: [
                // NOTE: _CodeFormatter gère lui-même le filtrage des chiffres
                // et insère l'espace — ne pas mettre digitsOnly ici car il
                // bloquerait l'espace produit par le formateur.
                _CodeFormatter(),
              ],
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
                color: Sp.g2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: '_ _ _  _ _ _',
                hintStyle: const TextStyle(
                    color: Sp.white40,
                    fontSize: 36,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w300),
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Sp.g2, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 24),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 28),

          // Bouton Valider
          GestureDetector(
            onTap: _loading ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 54,
              decoration: BoxDecoration(
                gradient: _loading ? null : kGrad,
                color: _loading ? Sp.card : null,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Connecter la TV',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 32),

          // Note sécurité
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              children: [
                Icon(Icons.security_rounded, color: Sp.white70, size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Le code est à usage unique et expire dans 5 minutes. '
                    'Ne le partagez jamais.',
                    style: TextStyle(color: Sp.white70, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Onglet 2 : Scanner QR ─────────────────────────────────────────────────────
  Widget _buildScannerTab() {
    return Column(
      children: [
        // Feedback
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _FeedbackBanner(message: _error!, isError: true),
          ),
        if (_success != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _FeedbackBanner(message: _success!, isError: false),
          ),

        // Viewfinder
        Expanded(
          child: _success != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => kGrad.createShader(b),
                        child: const Icon(Icons.check_circle_rounded,
                            size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('TV connectée !',
                          style: TextStyle(
                              color: Sp.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _success       = null;
                            _scanned       = false;
                            _scannerActive = true;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded,
                            color: Sp.white70),
                        label: const Text('Scanner une autre TV',
                            style: TextStyle(color: Sp.white70)),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    if (_scannerActive)
                      MobileScanner(
                        onDetect: (capture) {
                          final barcode = capture.barcodes.firstOrNull;
                          if (barcode?.rawValue != null) {
                            _onScan(barcode!.rawValue!);
                          }
                        },
                      ),
                    // Overlay avec viseur
                    Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Sp.g2.withOpacity(0.8), width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    // Instruction en bas
                    const Positioned(
                      bottom: 32,
                      left: 0, right: 0,
                      child: Text(
                        'Pointez la caméra vers le code affiché sur la TV',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    if (_loading)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: Sp.g2),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Auto-formateur "XXX XXX" ──────────────────────────────────────────────────
class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Garder uniquement les chiffres
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 6) {
      // Tronquer à 6 chiffres
      final truncated = digits.substring(0, 6);
      final formatted = '${truncated.substring(0, 3)} ${truncated.substring(3)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    if (digits.length >= 4) {
      final formatted =
          '${digits.substring(0, 3)} ${digits.substring(3)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

// ── Banner feedback ───────────────────────────────────────────────────────────
class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool   isError;
  const _FeedbackBanner({required this.message, required this.isError});
  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.redAccent : Colors.greenAccent.shade400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
