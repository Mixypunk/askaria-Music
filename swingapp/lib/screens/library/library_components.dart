part of '../library_tab.dart';

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String label;
  _EmptyView({required this.icon, required this.label});
  @override
  Widget build(BuildContext ctx) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Sp.card, borderRadius: BorderRadius.circular(18)),
        child: Icon(icon, color: Sp.white40, size: 36),
      ),
      SizedBox(height: 16),
      Text(label, style: TextStyle(
          color: Sp.white70, fontSize: 16)),
    ],
  ));
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext ctx) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Sp.card, borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.error_outline, color: Sp.white40, size: 36),
      ),
      SizedBox(height: 12),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(error, style: TextStyle(
            color: Sp.white70, fontSize: 12),
          textAlign: TextAlign.center)),
      SizedBox(height: 16),
      TextButton(onPressed: onRetry,
        child: Text('Réessayer',
            style: TextStyle(color: Sp.g2, fontWeight: FontWeight.w600))),
    ],
  ));
}

// ── Favoris ────────────────────────────────────────────────────────────────────
