import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../providers/player_provider.dart';

class TimerSheet {
  static void show(BuildContext context, PlayerProvider player) {
    int sliderValue = 15; // Valeur par défaut initiale
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                color: const Color(0xFF282828).withValues(alpha: 0.7),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                  const Row(children: [
                    Icon(Icons.bedtime_rounded, color: Colors.blueAccent, size: 22),
                    SizedBox(width: 10),
                    Text('Timer de sommeil', style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 30),
                  
                  // Compteur dynamique
                  Text('${sliderValue} min', 
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 42, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  // Slider interactif
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.blueAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.blueAccent.withValues(alpha: 0.2),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    ),
                    child: Slider(
                      value: sliderValue.toDouble(),
                      min: 1,
                      max: 120,
                      divisions: 119,
                      onChanged: (val) {
                        setState(() => sliderValue = val.toInt());
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Bouton Valider
                  GestureDetector(
                    onTap: () { 
                      player.setSleepTimer(sliderValue); 
                      Navigator.pop(context); 
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Text('Démarrer le timer',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold))))),
                  
                  if (player.hasSleepTimer) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () { player.cancelSleepTimer(); Navigator.pop(context); },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                          borderRadius: BorderRadius.circular(8)),
                        child: const Center(child: Text('Annuler le timer actuel',
                          style: TextStyle(color: Colors.redAccent,
                              fontWeight: FontWeight.bold))))),
                  ],
                ]),
              ),
            ),
          );
        }
      ),
    );
  }
}
