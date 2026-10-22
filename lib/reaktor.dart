import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'tema.dart';

enum ModeJarvis { siaga, dengar, mikir }

/// Reaktor "J" animasi: berputar lebih cepat saat mendengar atau berpikir.
class Reaktor extends StatefulWidget {
  const Reaktor({super.key, required this.mode, this.ukuran = 140});
  final ModeJarvis mode;
  final double ukuran;
  @override
  State<Reaktor> createState() => _ReaktorState();
}

class _ReaktorState extends State<Reaktor> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _tik = ValueNotifier<int>(0);
  Duration _terakhir = Duration.zero;
  double a1 = 0, a2 = 0, denyut = 0;

  double get _kecepatan => switch (widget.mode) { ModeJarvis.siaga => 1.0, ModeJarvis.dengar => 4.0, ModeJarvis.mikir => 7.0 };

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      final dt = (e - _terakhir).inMicroseconds / 1e6;
      _terakhir = e;
      final k = _kecepatan;
      a1 += dt * 0.15 * k;
      a2 -= dt * 0.5 * k;
      denyut += dt * (1.5 + k * 0.5);
      _tik.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tik.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.ukuran,
        height: widget.ukuran,
        child: CustomPaint(painter: _Lukis(this, _tik)),
      );
}

class _Lukis extends CustomPainter {
  _Lukis(this.s, Listenable repaint) : super(repaint: repaint);
  final _ReaktorState s;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Titik-titik luar
    final titik = Paint()..color = W.glow.withAlpha(170);
    for (var i = 0; i < 60; i++) {
      final a = s.a1 + i * 2 * math.pi / 60;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r * 0.94), 1.2, titik);
    }

    // Empat busur tebal
    final rect = Rect.fromCircle(center: c, radius: r * 0.82);
    final busurGlow = Paint()
      ..color = W.glow.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final busur = Paint()
      ..color = W.glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final mulai = s.a2 + i * math.pi / 2;
      canvas.drawArc(rect, mulai, math.pi / 2 * 0.62, false, busurGlow);
      canvas.drawArc(rect, mulai, math.pi / 2 * 0.62, false, busur);
    }

    // Lingkaran tipis
    canvas.drawCircle(c, r * 0.66, Paint()..color = W.glow.withAlpha(150)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Inti berdenyut
    final isi = 25 + ((math.sin(s.denyut) + 1) / 2 * 55).round();
    canvas.drawCircle(c, r * 0.48, Paint()..color = W.glow.withAlpha(isi));
    canvas.drawCircle(c, r * 0.48, Paint()..color = W.glow..style = PaintingStyle.stroke..strokeWidth = 2.5);

    // Huruf J
    final tp = TextPainter(
      text: TextSpan(text: 'J', style: TextStyle(color: Colors.white, fontSize: r * 0.62, fontWeight: FontWeight.w800, shadows: const [Shadow(color: W.glow, blurRadius: 14)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
