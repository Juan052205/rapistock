import 'package:flutter/material.dart';
import '../data/reports.dart';
import '../models/types.dart';
import '../theme.dart';

class StockMeter extends StatelessWidget {
  final Producto producto;
  const StockMeter({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    final nivel = nivelStock(producto);
    final healthy = (producto.stockMinimo * 3).clamp(1, 1 << 20);
    final pct = (producto.stockActual / healthy).clamp(0.0, 1.0);
    final color = switch (nivel) {
      NivelStock.ok => R.ok,
      NivelStock.bajo => R.warn,
      NivelStock.agotado => R.danger,
    };
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: nivel == NivelStock.agotado ? 0.04 : pct,
              minHeight: 6,
              color: color,
              backgroundColor: const Color(0xFFEBE6D9),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${producto.stockActual}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}