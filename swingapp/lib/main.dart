import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'providers/downloads_provider.dart';
import 'services/api_service.dart';
import 'services/theme_notifier.dart';
import 'services/widget_service.dart';
import 'services/update_service.dart';
import 'screens/root_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/eq_screen.dart';
import 'package:just_audio_background/just_audio_background.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
class Sp {
  static const bg      = Color(0xFF121212);
  static const surface = Color(0xFF181818);
  static const card    = Color(0xFF282828);
  static const cardHi  = Color(0xFF3E3E3E);
  static const white   = Color(0xFFFFFFFF);
  static const white70 = Color(0xFFB3B3B3);
  static const white40 = Color(0xFF6A6A6A);
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

class GBtn extends StatelessWidget {
  final String label; final VoidCallback? onTap; final bool loading;
  const GBtn(this.label, {super.key, this.onTap, this.loading = false});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(gradient: kGrad,
          borderRadius: BorderRadius.circular(24)),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  );
}

// ── Point d'entrée ─────────────────────────────────────────────────────────────
Future<void> main() async {
  // Gestionnaire d'erreurs global — évite les crashes silencieux
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: \${details.exceptionAsString()}');
  };
  WidgetsFlutterBinding.ensureInitialized();

  // Barre de statut transparente dès le départ
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Sp.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Démarrer l'app immédiatement avec un splash — l'auth se fait en arrière-plan
  runApp(const _SplashWrapper());
}

// ── Splash → Auth → App ────────────────────────────────────────────────────────
class _SplashWrapper extends StatefulWidget {
  const _SplashWrapper();
  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper> {
  bool _ready = false;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Init arrière-plan audio
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.mixypunk.askaria.channel.audio',
        androidNotificationChannelName: 'Askaria Music',
        // false = permet d'afficher les boutons prev/next dans la notification
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        notificationColor: const Color(0xFF1A1A2E),
        androidNotificationIcon: 'mipmap/ic_launcher',
      );
    } catch (e) {
      debugPrint('JustAudioBackground init error: \$e');
    }
    try {
      await ThemeNotifier.instance.load();
      final api = SwingApiService();
      await api.loadSettings();
      // checkAuth retourne true même hors ligne si un token est présent
      // (mode offline — l'user peut écouter les titres téléchargés)
      _logged = await api.checkAuth();
    } catch (e) {
      debugPrint('Auth error: $e');
      // En cas d'erreur inattendue : connecté si token présent
      _logged = SwingApiService().isLoggedIn;
    }
    if (mounted) setState(() => _ready = true);
  }

  void _setupWidgetActions(PlayerProvider player) {
    WidgetService.instance.onAction = (action) {
      switch (action) {
        case 'prev': player.previous(); break;
        case 'play': player.playPause(); break;
        case 'next': player.next(); break;
      }
    };
    WidgetService.instance.startListening();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _SplashScreen();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider.value(value: ThemeNotifier.instance),
      ],
      child: _App(_logged),
    );
  }
}

// ── Écran de splash ────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Sp.bg,
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Askaria depuis les assets réseau (ou fallback icône)
            Image.network(
              'https://askaria-music.duckdns.org/static/logo.webp',
              width: 200,
              errorBuilder: (_, __, ___) => ShaderMask(
                shaderCallback: (b) => kGradV.createShader(b),
                child: const Icon(Icons.music_note_rounded,
                    size: 72, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                  color: Sp.g2, strokeWidth: 2),
            ),
          ],
        )),
      ),
    );
  }
}

// ── App principale ─────────────────────────────────────────────────────────────
class _App extends StatelessWidget {
  final bool logged;
  const _App(this.logged);
  @override
  Widget build(BuildContext ctx) => Consumer<ThemeNotifier>(
    builder: (ctx, theme, _) => MaterialApp(
    title: 'Askaria',
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
        titleTextStyle: TextStyle(color: Sp.white,
            fontSize: 18, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Sp.white),
    ),
    initialRoute: logged ? '/root' : '/login',
    routes: {
      '/login':   (_) => const LoginScreen(),
      '/root':    (_) => const RootScreen(),
      '/profile': (_) => const ProfileScreen(),
      '/eq':      (_) => const EqScreen(),
    },
    builder: (ctx, child) => _UpdateChecker(child: child!),
  ),   // MaterialApp
  );   // Consumer<ThemeNotifier>
}

// ── Vérification mise à jour ───────────────────────────────────────────────────
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
    // Délai pour ne pas bloquer le rendu initial
    Future.delayed(const Duration(seconds: 5), _check);
  }

  Future<void> _check() async {
    final info = await UpdateService().checkOnce();
    if (info != null && mounted) await UpdateDialog.show(context, info);
  }

  @override
  Widget build(BuildContext ctx) => widget.child;
}
