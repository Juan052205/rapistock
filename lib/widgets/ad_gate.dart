import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

Future<bool> anuncioSiGratis(BuildContext context, {required bool esPro}) async {
  if (esPro) return true;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AdGate(
      onAdFinished: () => Navigator.of(ctx).pop(true),
      onPreferPro: () => Navigator.of(ctx).pop(false),
    ),
  );
  return ok == true;
}

class AdGate extends StatefulWidget {
  final VoidCallback onAdFinished;
  final VoidCallback onPreferPro;
  const AdGate({super.key, required this.onAdFinished, required this.onPreferPro});

  @override
  State<AdGate> createState() => _AdGateState();
}

class _AdGateState extends State<AdGate> {
  int left = 4;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (left <= 1) {
        timer.cancel();
        widget.onAdFinished();
      } else {
        setState(() => left--);
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Un aviso corto'),
      content: Text('En la versión gratis hay un aviso de $left s. Pro los quita todos.'),
      actions: [
        TextButton(onPressed: widget.onPreferPro, child: const Text('Prefiero Pro')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: R.forest),
          onPressed: left > 1 ? null : widget.onAdFinished,
          child: Text(left > 1 ? 'Espera $left' : 'Continuar'),
        ),
      ],
    );
  }
}