import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service qui fait le pont entre PlayerProvider et le widget Android.
/// - Envoie les mises à jour (titre, artiste, pochette, état lecture) au widget
/// - Reçoit les actions du widget (précédent, play/pause, suivant)
class WidgetService {
  static const _channel = MethodChannel('com.mixypunk.askasound/widget');
  static const _events  = EventChannel('com.mixypunk.askasound/widget_events');

  static WidgetService? _instance;
  static WidgetService get instance => _instance ??= WidgetService._();
  WidgetService._();

  /// Callback appelé quand l'utilisateur appuie sur un bouton du widget.
  /// Valeurs possibles : "prev", "play", "next"
  Function(String action)? onAction;

  bool _listening = false;

  /// Démarre l'écoute des actions du widget (appeler au démarrage de l'app).
  void startListening() {
    if (_listening) return;
    _listening = true;
    _events.receiveBroadcastStream().listen((event) {
      final action = event as String?;
      if (action != null) {
        debugPrint('Widget action: $action');
        onAction?.call(action);
      }
    }, onError: (e) {
      debugPrint('Widget events error: $e');
    });
  }

  /// Met à jour le widget avec les infos du titre en cours.
  Future<void> update({
    required String title,
    required String artist,
    required String artUrl,
    required bool isPlaying,
    String? authToken,
  }) async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'title':      title,
        'artist':     artist,
        'art_url':    artUrl,
        'playing':    isPlaying,
        'auth_token': authToken ?? '',
      });
    } catch (e) {
      debugPrint('Widget update error: \$e');
    }
  }
}
