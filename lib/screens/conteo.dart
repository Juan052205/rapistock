import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/stock_meter.dart';

class ConteoPantalla extends StatefulWidget {
  const ConteoPantalla({super.key});

  @override
  State<ConteoPantalla> createState() => _ConteoPantallaState();
}

class _ConteoPantallaState extends State<ConteoPantalla> {
  late Map<int, TextEditingController> draft;
  String q = '';
  bool ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ready) return;
    final productos = context.read<Store>().productos;
    draft = {
      for (final p in productos)
        if (p.id != null) p.id!: TextEditingController(text: '${p.stockActual}'),
    };
    ready = true;
  }

  @override
  void dispose() {
    if (ready) {
      for (final c in draft.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final n = q.trim().toLowerCase();
    final filas = store.productos.where((p) {
      if (p.id == null) return false;
      if (n.isEmpty) return true;
      return p.nombre.toLowerCase().contains(n) ||
          p.codigoRef.toLowerCase().contains(n) ||
          p.ubicacion.toLowerCase().contains(n);
    }).map((p) {
      final raw = draft[p.id]?.text ?? '${p.stockActual}';
      final contado = int.tryParse(raw) ?? 0;
      return (p: p, contado: contado < 0 ? 0 : contado, delta: (int.tryParse(raw) ?? 0) - p.stockActual);
    }).toList();
    final cambios = filas.where((f) => f.delta != 0).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Contar lo del estante')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Escribe lo que hay en el estante. La app arma la corrección en el historial.'),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Producto, código o pasillo...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filas.length,
              itemBuilder: (_, i) {
                final f = filas[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(f.p.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                        if (f.delta != 0)
                          Text(
                            f.delta > 0 ? '+${f.delta}' : '${f.delta}',
                            style: TextStyle(fontWeight: FontWeight.w800, color: f.delta > 0 ? R.ok : R.danger),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${f.p.codigoRef} · en la app ${f.p.stockActual} ${f.p.unidad} · ${f.p.ubicacion}', style: const TextStyle(fontSize: 11)),
                        StockMeter(producto: f.p),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 72,
                      child: TextField(
                        controller: draft[f.p.id],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(child: Text(cambios == 0 ? 'Sin diferencias todavía' : '$cambios ${cambios == 1 ? 'corrección' : 'correcciones'} pendientes')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: R.forest, minimumSize: const Size(140, 48)),
                    onPressed: cambios == 0
                        ? null
                        : () async {
                      final r = await store.aplicarConteo(
                        filas.map((f) => (productoId: f.p.id!, contado: f.contado)).toList(),
                      );
                      if (!context.mounted) return;
                      if (!r.ok) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay diferencias con la app')));
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Conteo aplicado · ${r.count} ${r.count == 1 ? 'corrección' : 'correcciones'}')),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Aplicar conteo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}