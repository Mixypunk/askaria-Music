import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/connect_controller_provider.dart';
import 'services/api_service.dart';
import 'services/theme_notifier.dart';
import 'services/network_quality_service.dart';
import 'services/widget_service.dart';
import 'services/update_service.dart';
import 'screens/root_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'package:just_audio_background/just_audio_background.dart';

// ── Palette (theme-aware) ───────────────────────────────────────────────────────
class Sp {
  Sp._();
  static bool get _dark => ThemeNotifier.instance.isDark;

  // Backgrounds
  static Color get bg      => _dark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5);
  static Color get bg2     => _dark ? const Color(0xFF111111) : const Color(0xFFEEEEEE);
  static Color get surface => _dark ? const Color(0xFF161616) : const Color(0xFFE8E8E8);
  static Color get card    => _dark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  static Color get cardHi  => _dark ? const Color(0xFF252525) : const Color(0xFFF0F0F0);
  static Color get glass   => _dark ? const Color(0x14FFFFFF) : const Color(0x14000000);

  // Text / icon colors (inverted for light)
  static Color get white   => _dark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);
  static Color get white70 => _dark ? const Color(0xFFB3B3B3) : const Color(0xFF555555);
  static Color get white40 => _dark ? const Color(0xFF666666) : const Color(0xFF999999);
  static Color get white12 => _dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000);

  // Accent gradients – brand colors, same in both themes
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

const kGradBottom = LinearGradient(
  colors: [Colors.transparent, Color(0xCC000000)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

/// Décoration glass (frosted)
BoxDecoration kGlassDecoration({
  double radius = 16,
  Color border = const Color(0x20FFFFFF),
}) => BoxDecoration(
  color: Sp.glass,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: border, width: 0.8),
);

/// Card standard épurée
BoxDecoration kCardDecoration({double radius = 16}) => BoxDecoration(
  color: Sp.card,
  borderRadius: BorderRadius.circular(radius),
);

// ── Helpers UI ─────────────────────────────────────────────────────────────────
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

/// Bouton gradient avec ombre diffuse
class GBtn extends StatelessWidget {
  final String label; final VoidCallback? onTap; final bool loading;
  const GBtn(this.label, {super.key, this.onTap, this.loading = false});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: kGrad,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Sp.g2.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15,
              letterSpacing: 0.3)),
    ),
  );
}

/// Container Glass avec blur
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.blur = 12,
  });
  @override
  Widget build(BuildContext ctx) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        padding: padding,
        decoration: kGlassDecoration(radius: radius),
        child: child,
      ),
    ),
  );
}

// ── Point d'entrée ─────────────────────────────────────────────────────────────
Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter error: \${details.exceptionAsString()}');
  };
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D0D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

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
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.mixypunk.askaria.channel.audio',
        androidNotificationChannelName: 'Askaria Music',
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
      await NetworkQualityService.instance.load();
      final api = SwingApiService();
      await api.loadSettings();
      _logged = await api.checkAuth();
    } catch (e) {
      debugPrint('Auth error: $e');
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
        ChangeNotifierProvider(create: (_) {
          final p = PlayerProvider();
          _setupWidgetActions(p);
          return p;
        }),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => ConnectControllerProvider()),
        ChangeNotifierProvider.value(value: ThemeNotifier.instance),
      ],
      child: _App(_logged),
    );
  }
}

// ── Écran de splash ────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Sp.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _glow,
                builder: (_, child) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Sp.g2.withValues(alpha: 0.3 + _glow.value * 0.25),
                        blurRadius: 40 + _glow.value * 30,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Image.asset(
                  'assets/logo.webp',
                  width: 120,
                  errorBuilder: (_, __, ___) => ShaderMask(
                    shaderCallback: (b) => kGradV.createShader(b),
                    child: const Icon(Icons.music_note_rounded,
                        size: 80, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  color: Sp.g2.withValues(alpha: 0.7),
                  strokeWidth: 1.5,
                ),
              ),
            ],
          ),
        ),
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
    themeMode: theme.mode,
    // ── Dark theme ──
    darkTheme: ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      colorScheme: const ColorScheme.dark(
        primary: Sp.g2, secondary: Sp.g3,
        surface: Color(0xFF161616), surfaceContainer: Color(0xFF0D0D0D),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
        bodyMedium: TextStyle(color: Color(0xFFB3B3B3)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
        titleTextStyle: TextStyle(color: Color(0xFFFFFFFF),
            fontSize: 18, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
      splashColor: Colors.white10,
      highlightColor: Colors.white10,
    ),
    // ── Light theme ──
    theme: ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      colorScheme: const ColorScheme.light(
        primary: Sp.g2, secondary: Sp.g3,
        surface: Color(0xFFE8E8E8), surfaceContainer: Color(0xFFF5F5F5),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF555555)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        titleTextStyle: TextStyle(color: Color(0xFF1A1A1A),
            fontSize: 18, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      splashColor: Colors.black12,
      highlightColor: Colors.black12,
    ),
    initialRoute: logged ? '/root' : '/login',
    routes: {
      '/login':   (_) => LoginScreen(),
      '/root':    (_) => const RootScreen(),
      '/profile': (_) => ProfileScreen(),
    },
    builder: (ctx, child) => _UpdateChecker(child: child!),
  ),
  );
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
    Future.delayed(const Duration(seconds: 5), _check);
  }

  Future<void> _check() async {
    final info = await UpdateService().checkOnce();
    if (info != null && mounted) await UpdateDialog.show(context, info);
  }

  @override
  Widget build(BuildContext ctx) => widget.child;
}

