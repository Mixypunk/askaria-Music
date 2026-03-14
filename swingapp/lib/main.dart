import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
class AppColors {
  // Gradient bleu → violet → rose
  static const grad1 = Color(0xFF4776E6); // bleu
  static const grad2 = Color(0xFF8E54E9); // violet
  static const grad3 = Color(0xFFD63AF9); // rose/magenta

  // Backgrounds
  static const bg       = Color(0xFF0D0D14);
  static const surface  = Color(0xFF161625);
  static const card     = Color(0xFF1E1E30);
  static const cardHigh = Color(0xFF252538);

  // Text
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9D9DB8);
  static const textDisabled  = Color(0xFF4D4D6A);
}

const kGradient = LinearGradient(
  colors: [AppColors.grad1, AppColors.grad2, AppColors.grad3],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const kGradientV = LinearGradient(
  colors: [AppColors.grad1, AppColors.grad2, AppColors.grad3],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SwingApiService().loadSettings();
  final isLoggedIn = await SwingApiService().checkAuth();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PlayerProvider())],
      child: SwingApp(isLoggedIn: isLoggedIn),
    ),
  );
}

class SwingApp extends StatelessWidget {
  final bool isLoggedIn;
  const SwingApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwingApp',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      initialRoute: isLoggedIn ? '/home' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home':  (_) => const HomeScreen(),
      },
    );
  }

  ThemeData _theme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary:       AppColors.grad2,
      secondary:     AppColors.grad3,
      surface:       AppColors.surface,
      onSurface:     AppColors.textPrimary,
      surfaceVariant: AppColors.card,
      onSurfaceVariant: AppColors.textSecondary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.textPrimary,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: Colors.transparent,
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.grad2,
      inactiveTrackColor: AppColors.card,
      thumbColor: Colors.white,
      overlayColor: Colors.transparent,
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: AppColors.textSecondary,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    dividerColor: Colors.white10,
  );
}

// ── Gradient helper widgets ────────────────────────────────────────────────────
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const GradientText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (b) => kGradient.createShader(b),
    child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
  );
}

class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const GradientIcon(this.icon, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (b) => kGradient.createShader(b),
    child: Icon(icon, size: size, color: Colors.white),
  );
}

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const GradientButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    decoration: BoxDecoration(
      gradient: kGradient,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onPressed,
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    ),
  );
}
