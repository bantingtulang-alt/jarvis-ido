import 'package:flutter/material.dart';

class W {
  static const bg = Color(0xFF030812);
  static const panel = Color(0xCC081A2C);
  static const garis = Color(0xFF17496A);
  static const glow = Color(0xFF35D0FF);
  static const teks = Color(0xFFDFF6FF);
  static const redup = Color(0xFF7FA6BD);
  static const ok = Color(0xFF5DFFB0);
  static const peringatan = Color(0xFFFFB86B);
  static const buruk = Color(0xFFFF6B7A);
}

ThemeData buatTema() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: W.bg,
      colorScheme: const ColorScheme.dark(primary: W.glow, surface: W.bg),
      textTheme: ThemeData.dark().textTheme.apply(bodyColor: W.teks, displayColor: W.teks),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xE6041221),
        hintStyle: const TextStyle(color: W.redup),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: W.garis)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: W.garis)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: W.glow, width: 1.5)),
      ),
    );

/// Kotak bergaya HUD untuk kartu dan panel.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.terang = false});
  final Widget child;
  final bool terang;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: W.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: terang ? W.glow : W.garis),
          boxShadow: terang ? [BoxShadow(color: W.glow.withAlpha(40), blurRadius: 14)] : null,
        ),
        child: child,
      );
}

class TombolIsi extends StatelessWidget {
  const TombolIsi(this.label, this.onTap, {super.key, this.garis = false});
  final String label;
  final VoidCallback? onTap;
  final bool garis;
  @override
  Widget build(BuildContext context) => garis
      ? OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(foregroundColor: W.teks, side: const BorderSide(color: W.garis), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: Text(label))
      : FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(backgroundColor: W.glow, foregroundColor: const Color(0xFF02101C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)));
}
