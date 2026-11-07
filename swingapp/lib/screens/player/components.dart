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
class _ProgressBar extends StatefulWidget {
  final Color accent;
  const _ProgressBar({required this.accent});

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext ctx) {
    return Consumer2<PlayerProvider, ConnectControllerProvider>(
      builder: (ctx, p, c, _) {
        final pos = c.isConnected ? c.position : p.position;
        final dur = c.isConnected ? c.duration : p.duration;
        final maxMs = dur.inMilliseconds.toDouble() > 0
            ? dur.inMilliseconds.toDouble()
            : 1.0;
        final currentMs = _dragValue ?? pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

        return SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: widget.accent,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: widget.accent.withOpacity(0.2)),
          child: Slider(
            min: 0.0,
            max: maxMs,
            value: currentMs.clamp(0.0, maxMs),
            onChangeStart: (v) {
              setState(() => _dragValue = v);
            },
            onChanged: (v) {
              setState(() => _dragValue = v);
            },
            onChangeEnd: (v) {
              final target = Duration(milliseconds: v.round());
              if (c.isConnected) {
                c.seek(target);
              } else {
                p.seek(target);
              }
              setState(() => _dragValue = null);
            },
          ),
        );
      },
    );
  }
}

class _VolumeBar extends StatefulWidget {
  final Color accent;
  const _VolumeBar({required this.accent});

  @override
  State<_VolumeBar> createState() => _VolumeBarState();
}

class _VolumeBarState extends State<_VolumeBar> {
  double? _dragVolume;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, p, __) {
        final currentVol = (_dragVolume ?? p.volume).clamp(0.0, 1.0);
        return Row(children: [
          Icon(
            currentVol == 0
                ? Icons.volume_off_rounded
                : currentVol < 0.5
                    ? Icons.volume_down_rounded
                    : Icons.volume_up_rounded,
            size: 18, color: Colors.white38),
          Expanded(child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: widget.accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: widget.accent.withOpacity(0.2)),
            child: Slider(
              value: currentVol,
              onChangeStart: (v) => setState(() => _dragVolume = v),
              onChanged: (v) {
                setState(() => _dragVolume = v);
                p.setVolume(v);
              },
              onChangeEnd: (v) {
                p.setVolume(v);
                setState(() => _dragVolume = null);
              },
            ),
          )),
          const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white38),
        ]);
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

