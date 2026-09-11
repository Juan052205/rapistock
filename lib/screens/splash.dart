import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/logo_marca.dart';
import 'marco.dart';

class SplashPantalla extends StatefulWidget {
  const SplashPantalla({super.key});

  @override
  State<SplashPantalla> createState() => _SplashPantallaState();
}

class _SplashPantallaState extends State<SplashPantalla> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  late final Animation<double> scale;
  late final Animation<double> fade;

  @override
  void initState() {
    super.initState();
    c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    scale = CurvedAnimation(parent: c, curve: Curves.easeOutBack);
    fade = CurvedAnimation(parent: c, curve: const Interval(0.35, 1, curve: Curves.easeOut));
    c.forward();
    Future<void>.delayed(const Duration(milliseconds: 2100), _ir);
  }

  Future<void> _ir() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) => const MarcoPantalla(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: R.forest,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: c,
          builder: (context, child) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.72 + (scale.value * 0.28),
                    child: Opacity(
                      opacity: scale.value.clamp(0.0, 1.0),
                      child: const LogoMarca(size: 128),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Opacity(
                    opacity: fade.value,
                    child: const Column(
                      children: [
                        Text(
                          'Rapistock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tu bodega, clara',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}