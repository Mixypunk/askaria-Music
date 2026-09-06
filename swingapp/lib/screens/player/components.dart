part of '../player_screen.dart';

class _PageDots extends StatelessWidget {
  final int current;
  final Color accent;
  final int count; // 2 si pas de paroles, 3 sinon
  const _PageDots({required this.current, required this.accent,
      this.count = 3});
  @override
  Widget build(BuildContext ctx) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(count, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: i == current ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: i == current ? accent : Colors.white24,
        borderRadius: BorderRadius.circular(3)),
    )),
  );
}

// ── Page Player ────────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final Color accent;
  const _ProgressBar({required this.accent});

  @override
  Widget build(BuildContext ctx) {
    return Consumer2<PlayerProvider, ConnectControllerProvider>(
      builder: (ctx, p, c, _) {
        final pos = c.isConnected ? c.position : p.position;
        final dur = c.isConnected ? c.duration : p.duration;
        final maxMs = dur.inMilliseconds.toDouble() > 0
            ? dur.inMilliseconds.toDouble()
            : 1.0;
        return SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: accent.withOpacity(0.2)),
          child: Slider(
            min: 0.0,
            max: maxMs,
            value: pos.inMilliseconds.toDouble().clamp(0.0, maxMs),
            onChanged: (v) {
              if (c.isConnected) {
                c.seek(Duration(milliseconds: v.round()));
              } else {
                p.seek(Duration(milliseconds: v.round()));
              }
            },
          ),
        );
      },
    );
  }
}

// ── Page Paroles ───────────────────────────────────────────────────────────────
class _ShareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShareBtn(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 26)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 60, child: Text(label,
        style: const TextStyle(color: Colors.white54, fontSize: 13))),
      Expanded(child: Text(value,
        style: const TextStyle(color: Colors.white, fontSize: 13))),
    ]),
  );
}

// ── Page File d'attente ────────────────────────────────────────────────────────

