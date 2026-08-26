import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/eq_service.dart';

class EqScreen extends StatefulWidget {
  const EqScreen({super.key});
  @override
  State<EqScreen> createState() => _EqScreenState();
}

class _EqScreenState extends State<EqScreen> {
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    EqService.instance.getBandLabels().then((l) {
      if (mounted && l.isNotEmpty) setState(() => _labels = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      appBar: AppBar(
        backgroundColor: Sp.bg,
        title: const Text('Égaliseur',
            style: TextStyle(color: Sp.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Sp.white, size: 20),
          onPressed: () => Navigator.pop(context)),
      ),
      body: ChangeNotifierProvider.value(
        value: EqService.instance,
        child: Consumer<EqService>(
          builder: (ctx, eq, _) {
            final bands = eq.gains;
            if (bands.isEmpty) {
              return const Center(child: Text(
                'Égaliseur non disponible sur cet appareil.',
                style: TextStyle(color: Sp.white70),
                textAlign: TextAlign.center));
            }
            final labels = _labels.length == bands.length
                ? _labels
                : List.generate(bands.length, (i) => 'B${i+1}');

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Toggle + preset
                Row(children: [
                  const Text('Égaliseur',
                      style: TextStyle(color: Sp.white, fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Switch(
                    value: eq.enabled,
                    activeColor: Sp.g2,
                    onChanged: (v) => eq.setEnabled(v)),
                ]),
                const SizedBox(height: 16),

                // Sélecteur de presets
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: eq.presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final sel = eq.presetIdx == i;
                      return GestureDetector(
                        onTap: eq.enabled ? () => eq.setPreset(i) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: sel ? kGrad : null,
                            color: sel ? null : Sp.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? Colors.transparent
                                  : Colors.white12)),
                          child: Text(eq.presets[i].name,
                            style: TextStyle(
                              color: sel ? Colors.white : Sp.white70,
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),

                // Sliders par bande
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Sp.card,
                    borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    // Valeurs en dB
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(bands.length, (i) => SizedBox(
                        width: (MediaQuery.of(ctx).size.width - 64) / bands.length,
                        child: Text(
                          '${bands[i].toStringAsFixed(0)}dB',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: bands[i].abs() > 0.5
                                ? Sp.g2 : Sp.white40,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                      )),
                    ),
                    const SizedBox(height: 8),

                    // Sliders verticaux
                    SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(bands.length, (i) => Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                                activeTrackColor: Sp.g2,
                                inactiveTrackColor: Colors.white12,
                                thumbColor: eq.enabled
                                    ? Colors.white : Colors.white24,
                                overlayColor: Sp.g2.withValues(alpha: 0.15),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 16)),
                              child: Slider(
                                value: bands[i].clamp(-15.0, 15.0),
                                min: -15.0,
                                max: 15.0,
                                divisions: 30,
                                onChanged: eq.enabled
                                  ? (v) => eq.setBandGain(i, v)
                                  : null),
                            ),
                          ),
                        )),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Labels fréquences
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(bands.length, (i) => SizedBox(
                        width: (MediaQuery.of(ctx).size.width - 64) / bands.length,
                        child: Text(labels[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Sp.white70, fontSize: 10)),
                      )),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Bouton reset
                GestureDetector(
                  onTap: eq.enabled ? () => eq.setPreset(0) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded,
                            color: Sp.white70, size: 16),
                        SizedBox(width: 8),
                        Text('Réinitialiser',
                            style: TextStyle(color: Sp.white70, fontSize: 13)),
                      ]),
                  ),
                ),

                // Note Android
                const SizedBox(height: 20),
                const Text(
                  'L\'égaliseur utilise le moteur audio Android natif.\nLes fréquences disponibles dépendent de votre appareil.',
                  style: TextStyle(color: Sp.white40, fontSize: 11),
                  textAlign: TextAlign.center),
              ],
            );
          },
        ),
      ),
    );
  }
}
