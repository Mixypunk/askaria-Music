import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class WaveformSeekbar extends StatefulWidget {
  final String songHash;
  final double progress;         // 0.0 → 1.0
  final Duration position;
  final Duration duration;
  final void Function(double) onSeek;

  const WaveformSeekbar({
    super.key,
    required this.songHash,
    required this.progress,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<WaveformSeekbar> createState() => _WaveformSeekbarState();
}

class _WaveformSeekbarState extends State<WaveformSeekbar> {
  List<double> _peaks = [];
  String? _loadedHash;
  bool _loading = false;
  double? _dragProgress;

  @override
  void didUpdateWidget(WaveformSeekbar old) {
    super.didUpdateWidget(old);
    if (widget.songHash != old.songHash) {
      _loadWaveform();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWaveform();
  }

  Future<void> _loadWaveform() async {
    if (_loadedHash == widget.songHash || _loading) return;
    _loading = true;
    try {
      final api  = SwingApiService();
      final data = await api.getWaveform(widget.songHash);
      if (data != null && mounted) {
        setState(() {
          _peaks = data;
          _loadedHash = widget.songHash;
        });
      }
    } catch (_) {}
    _loading = false;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _dragProgress ?? widget.progress;

    return GestureDetector(
        onHorizontalDragUpdate: (d) {
          final box = context.findRenderObject() as RenderBox;
          final local = box.globalToLocal(d.globalPosition);
          setState(() => _dragProgress =
              (local.dx / box.size.width).clamp(0.0, 1.0));
        },
        onHorizontalDragEnd: (_) {
          if (_dragProgress != null) {
            widget.onSeek(_dragProgress!);
            setState(() => _dragProgress = null);
          }
        },
        onTapDown: (d) {
          final box = context.findRenderObject() as RenderBox;
          final local = box.globalToLocal(d.globalPosition);
          widget.onSeek((local.dx / box.size.width).clamp(0.0, 1.0));
        },
        child: SizedBox(
          height: 48,
          child: _peaks.isEmpty
              ? _FallbackSeekbar(progress: progress)
              : CustomPaint(
                  size: const Size(double.infinity, 48),
                  painter: _WaveformPainter(
                    peaks:    _peaks,
                    progress: progress,
                    activeColor:   Sp.g2,
                    inactiveColor: Colors.white24,
                  ),
                ),
        ),
      ),

    );
  }
}

// ── Fallback si pas de waveform (barre classique) ─────────────────────────────
class _FallbackSeekbar extends StatelessWidget {
  final double progress;
  const _FallbackSeekbar({required this.progress});
  @override
  Widget build(BuildContext ctx) => Center(child: ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: progress,
      minHeight: 3,
      backgroundColor: Colors.white12,
      valueColor: AlwaysStoppedAnimation(Sp.g2))));
}

// ── Painter waveform ──────────────────────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
    final barW   = (size.width / peaks.length) * 0.6;
    final gap    = (size.width / peaks.length) * 0.4;
    final midY   = size.height / 2;
    final minH   = 2.0;
    final progressX = size.width * progress;

    final paintA = Paint()..color = activeColor   ..strokeCap = StrokeCap.round;
    final paintI = Paint()..color = inactiveColor ..strokeCap = StrokeCap.round;

    for (int i = 0; i < peaks.length; i++) {
      final x    = i * (barW + gap) + barW / 2;
      final h    = (peaks[i] * size.height * 0.85).clamp(minH, size.height);
      final paint = x <= progressX ? paintA : paintI;
      paint.strokeWidth = barW.clamp(1.5, 4.0);
      canvas.drawLine(
        Offset(x, midY - h / 2),
        Offset(x, midY + h / 2),
        paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.peaks != peaks;
}
