import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = SwingApiService();
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _api.getMyProfile();
    if (mounted) setState(() { _profile = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Mon profil',
            style: TextStyle(color: Sp.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Sp.white, size: 20),
          onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Sp.g2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                _AvatarSection(
                    profile: _profile, api: _api, onUpdated: _load),
                const SizedBox(height: 32),
                _InfoSection(
                    profile: _profile, api: _api, onUpdated: _load),
                const SizedBox(height: 20),
                _PasswordSection(api: _api),
              ],
            ),
    );
  }
}

// ── Section avatar ─────────────────────────────────────────────────────────────
class _AvatarSection extends StatefulWidget {
  final Map<String, dynamic> profile;
  final SwingApiService api;
  final VoidCallback onUpdated;
  const _AvatarSection({required this.profile, required this.api,
      required this.onUpdated});
  @override
  State<_AvatarSection> createState() => _AvatarSectionState();
}

class _AvatarSectionState extends State<_AvatarSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery, imageQuality: 85, maxWidth: 600);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final url   = await widget.api.uploadAvatar(bytes);
      if (url != null && mounted) {
        widget.onUpdated();
        _showSnack('Photo de profil mise à jour !');
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Sp.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.profile['id'] as int? ?? 0;
    final avatarUrl = userId > 0 ? widget.api.getAvatarUrl(userId) : null;
    final username = widget.profile['username'] as String? ?? '';

    return Center(child: Column(children: [
      Stack(children: [
        GestureDetector(
          onTap: _uploading ? null : _pickAndUpload,
          child: Container(
            width: 110, height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: kGrad,
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(child: avatarUrl != null
                ? Image.network(
                    avatarUrl,
                    key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _DefaultAvatar(username),
                  )
                : _DefaultAvatar(username)),
          ),
        ),
        // Bouton caméra
        Positioned(
          bottom: 0, right: 0,
          child: GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: kGrad,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: Sp.g2.withValues(alpha: 0.4),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: _uploading
                  ? const Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera_alt_rounded,
                      size: 16, color: Colors.white),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Text(username,
        style: const TextStyle(color: Sp.white,
            fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      if (widget.profile['role'] == 'admin')
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: Sp.g2.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Sp.g2.withValues(alpha: 0.4))),
          child: const Text('Admin',
              style: TextStyle(color: Sp.g2, fontSize: 12,
                  fontWeight: FontWeight.bold))),
      const SizedBox(height: 4),
      Text('Appuyer sur la photo pour modifier',
        style: const TextStyle(color: Sp.white40, fontSize: 12)),
    ]));
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String username;
  const _DefaultAvatar(this.username);
  @override
  Widget build(BuildContext ctx) => Container(
    color: Sp.card,
    child: Center(child: Text(
      username.isNotEmpty ? username[0].toUpperCase() : '?',
      style: const TextStyle(color: Sp.white,
          fontSize: 40, fontWeight: FontWeight.bold))),
  );
}

// ── Section infos ──────────────────────────────────────────────────────────────
class _InfoSection extends StatefulWidget {
  final Map<String, dynamic> profile;
  final SwingApiService api;
  final VoidCallback onUpdated;
  const _InfoSection({required this.profile, required this.api,
      required this.onUpdated});
  @override
  State<_InfoSection> createState() => _InfoSectionState();
}

class _InfoSectionState extends State<_InfoSection> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _bioCtrl;
  String? _birthDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.profile['username'] ?? '');
    _emailCtrl    = TextEditingController(text: widget.profile['email']    ?? '');
    _bioCtrl      = TextEditingController(text: widget.profile['bio']      ?? '');
    _birthDate    = widget.profile['birth_date'] as String?;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.updateProfile(
        username:  _usernameCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        birthDate: _birthDate,
        bio:       _bioCtrl.text.trim(),
      );
      widget.onUpdated();
      if (mounted) _showSnack('Profil mis à jour !');
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''),
          error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime initial = now.subtract(const Duration(days: 365 * 25));
    if (_birthDate != null) {
      try { initial = DateTime.parse(_birthDate!); } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: Sp.g2, surface: Sp.card),
          dialogTheme: const DialogThemeData(backgroundColor: Sp.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _birthDate =
          '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Sp.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ProfileSectionLabel('Informations'),
      const SizedBox(height: 12),
      _ProfileField(
          label: "Nom d'utilisateur", ctrl: _usernameCtrl,
          icon: Icons.person_outline_rounded),
      const SizedBox(height: 10),
      _ProfileField(
          label: 'Adresse email', ctrl: _emailCtrl,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 10),
      // Date de naissance
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: Sp.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Sp.white12),
          ),
          child: Row(children: [
            const Icon(Icons.cake_outlined, color: Sp.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(
              _birthDate != null ? _fmtDate(_birthDate!) : 'Date de naissance',
              style: TextStyle(
                color: _birthDate != null ? Sp.white : Sp.white40,
                fontSize: 14))),
            if (_birthDate != null)
              GestureDetector(
                onTap: () => setState(() => _birthDate = null),
                child: const Icon(Icons.clear, color: Sp.white40, size: 18)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      _ProfileField(
          label: 'Bio (courte)', ctrl: _bioCtrl,
          icon: Icons.edit_note_rounded, maxLines: 3, maxLength: 300),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity,
        child: GBtn('Enregistrer',
            onTap: _saving ? null : _save, loading: _saving)),
    ],
  );

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) { return iso; }
  }
}

// ── Section mot de passe ───────────────────────────────────────────────────────
class _PasswordSection extends StatefulWidget {
  final SwingApiService api;
  const _PasswordSection({required this.api});
  @override
  State<_PasswordSection> createState() => _PasswordSectionState();
}

class _PasswordSectionState extends State<_PasswordSection> {
  final _currCtrl = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _saving = false;
  bool _obsC = true, _obsN = true, _obsF = true;

  @override
  void dispose() {
    _currCtrl.dispose(); _newCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_newCtrl.text != _confCtrl.text) {
      _showSnack('Les mots de passe ne correspondent pas', error: true);
      return;
    }
    if (_newCtrl.text.length < 6) {
      _showSnack('Au moins 6 caractères requis', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.changePassword(_currCtrl.text, _newCtrl.text);
      _currCtrl.clear(); _newCtrl.clear(); _confCtrl.clear();
      if (mounted) _showSnack('Mot de passe modifié !');
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''),
          error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : Sp.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ProfileSectionLabel('Mot de passe'),
      const SizedBox(height: 12),
      _ProfileField(
          label: 'Mot de passe actuel', ctrl: _currCtrl,
          icon: Icons.lock_outline_rounded,
          obscure: _obsC,
          suffixIcon: _eyeBtn(_obsC, () => setState(() => _obsC = !_obsC))),
      const SizedBox(height: 10),
      _ProfileField(
          label: 'Nouveau mot de passe', ctrl: _newCtrl,
          icon: Icons.lock_outline_rounded,
          obscure: _obsN,
          suffixIcon: _eyeBtn(_obsN, () => setState(() => _obsN = !_obsN))),
      const SizedBox(height: 10),
      _ProfileField(
          label: 'Confirmer le mot de passe', ctrl: _confCtrl,
          icon: Icons.lock_outline_rounded,
          obscure: _obsF,
          suffixIcon: _eyeBtn(_obsF, () => setState(() => _obsF = !_obsF))),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity,
        child: GBtn('Changer le mot de passe',
            onTap: _saving ? null : _change, loading: _saving)),
    ],
  );

  Widget _eyeBtn(bool obs, VoidCallback onTap) => IconButton(
    icon: Icon(obs ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: Sp.white70, size: 18),
    onPressed: onTap);
}

// ── Helpers ────────────────────────────────────────────────────────────────────
class _ProfileSectionLabel extends StatelessWidget {
  final String label;
  const _ProfileSectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
    style: const TextStyle(
      color: Sp.white40, fontSize: 11,
      letterSpacing: 1.5, fontWeight: FontWeight.w700));
}

class _ProfileField extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  const _ProfileField({
    required this.label, required this.ctrl, required this.icon,
    this.obscure = false, this.suffixIcon, this.keyboardType,
    this.maxLines = 1, this.maxLength,
  });
  @override
  State<_ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<_ProfileField> {
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
  Widget build(BuildContext ctx) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: Sp.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: _focused ? Sp.g2.withValues(alpha: 0.6) : Sp.white12,
        width: _focused ? 1.5 : 0.8)),
    child: TextField(
      controller: widget.ctrl,
      focusNode: _focus,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      style: const TextStyle(color: Sp.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.label,
        hintStyle: const TextStyle(color: Sp.white40),
        prefixIcon: Icon(widget.icon,
            color: _focused ? Sp.g2 : Sp.white70, size: 20),
        suffixIcon: widget.suffixIcon,
        border: InputBorder.none,
        counterStyle: const TextStyle(color: Sp.white40, fontSize: 10),
        contentPadding: const EdgeInsets.symmetric(vertical: 14)),
    ),
  );
}
