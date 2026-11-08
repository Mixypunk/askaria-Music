import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/theme_notifier.dart';

/// Force la reconstruction profonde de son sous-arbre au changement de thème.
///
/// La palette `Sp` (main.dart) est lue via des getters statiques qui ne
/// dépendent pas de `Theme.of(context)`. Les widgets qui n'utilisent que `Sp`
/// ne s'abonnent donc à aucun `InheritedWidget` : Flutter ne rappelle jamais
/// leur `build` quand `ThemeNotifier` change (seul `MaterialApp` / `Theme` est
/// reconstruit) et les couleurs restent celles de l'ancien thème.
///
/// Ici, on écoute le notifier et on marque tous les éléments descendants comme
/// « dirty » après la frame courante. Chaque `build` est rejoué et la nouvelle
/// palette s'applique partout, y compris aux routes empilées (Paramètres,
/// Profil, Stats…), sans recréer le `Navigator` : la pile de navigation et
/// l'état des écrans sont conservés.
///
/// Ce widget doit envelopper le `Navigator` via `MaterialApp.builder`.
class ThemeRebuilder extends StatefulWidget {
  final Widget child;
  const ThemeRebuilder({super.key, required this.child});

  @override
  State<ThemeRebuilder> createState() => _ThemeRebuilderState();
}

class _ThemeRebuilderState extends State<ThemeRebuilder> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _applySystemUi();
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Accorde la barre de statut et la barre de navigation système au thème.
  void _applySystemUi() {
    final dark = ThemeNotifier.instance.isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          dark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    ));
  }

  void _onThemeChanged() {
    _applySystemUi();
    if (_scheduled) return;
    _scheduled = true;
    // Post-frame : `MaterialApp` a déjà appliqué le nouveau `ThemeData` et on
    // est sorti de la phase de build (interdiction de `markNeedsBuild`).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _markSubtreeDirty(context as Element);
    });
  }

  void _markSubtreeDirty(Element parent) {
    parent.visitChildren((Element child) {
      child.markNeedsBuild();
      _markSubtreeDirty(child);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
