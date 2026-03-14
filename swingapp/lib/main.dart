import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'screens/root_screen.dart';
import 'screens/login_screen.dart';

// ── Spotify-like palette avec gradient bleu/violet/rose ───────────────────────
class Sp {
  static const bg       = Color(0xFF121212);
  static const surface  = Color(0xFF181818);
  static const card     = Color(0xFF282828);
  static const cardHi   = Color(0xFF3E3E3E);

  static const white    = Color(0xFFFFFFFF);
  static const white70  = Color(0xFFB3B3B3);
  static const white40  = Color(0xFF6A6A6A);

  // Gradient signature bleu→violet→rose (remplace le vert Spotify)
  static const g1 = Color(0xFF4776E6);
  static const g2 = Color(0xFF8E54E9);
  static const g3 = Color(0xFFD63AF9);
}

const kGrad = LinearGradient(
  colors: [Sp.g1, Sp.g2, Sp.g3],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const kGradV = LinearGradient(
  colors: [Sp.g1, Sp.g2, Sp.g3],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Helpers ────────────────────────────────────────────────────────────────────
class GText extends StatelessWidget {
  final String t; final TextStyle? s;
  const GText(this.t, {super.key, this.s});
  @override
  Widget build(BuildContext ctx) => ShaderMask(
    shaderCallback: (b) => kGrad.createShader(b),
    child: Text(t, style: (s ?? const TextStyle()).copyWith(color: Colors.white)),
  );
}

class GIcon extends StatelessWidget {
  final IconData icon; final double size;
  const GIcon(this.icon, {super.key, this.size = 24});
  @override
  Widget build(BuildContext ctx) => ShaderMask(
    shaderCallback: (b) => kGrad.createShader(b),
    child: Icon(icon, size: size, color: Colors.white),
  );
}

// Bouton gradient style Spotify (pill)
class GBtn extends StatelessWidget {
  final String label; final VoidCallback? onTap; final bool loading;
  const GBtn(this.label, {super.key, this.onTap, this.loading = false});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(gradient: kGrad, borderRadius: BorderRadius.circular(24)),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Sp.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SwingApiService().loadSettings();
  final ok = await SwingApiService().checkAuth();
  runApp(MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => PlayerProvider())],
    child: _App(ok),
  ));
}

class _App extends StatelessWidget {
  final bool logged;
  const _App(this.logged);
  @override
  Widget build(BuildContext ctx) => MaterialApp(
    title: 'AskaSound',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Sp.bg,
      colorScheme: const ColorScheme.dark(
        primary: Sp.g2, secondary: Sp.g3,
        surface: Sp.surface, background: Sp.bg,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Sp.white),
        bodyMedium: TextStyle(color: Sp.white70),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: IconThemeData(color: Sp.white),
        titleTextStyle: TextStyle(color: Sp.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Sp.white),
    ),
    initialRoute: logged ? '/root' : '/login',
    routes: {
      '/login': (_) => const LoginScreen(),
      '/root':  (_) => const RootScreen(),
    },
    builder: (ctx, child) => _UpdateChecker(child: child!),
  );
}

class _UpdateChecker extends StatefulWidget {
  final Widget child;
  const _UpdateChecker({required this.child});
  @override
  State<_UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<_UpdateChecker> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), _check);
  }
  Future<void> _check() async {
    final info = await UpdateService().checkOnce();
    if (info != null && mounted) await UpdateDialog.show(context, info);
  }
  @override
  Widget build(BuildContext ctx) => widget.child;
}
