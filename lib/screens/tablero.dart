import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/exportar.dart';
import '../data/format.dart';
import '../data/reports.dart';
import '../data/store.dart';
import '../models/types.dart';
import '../theme.dart';
import '../widgets/ad_gate.dart';
import 'conteo.dart';
import '../data/play_billing_service.dart';
import 'escritorio.dart';

class TableroPantalla extends StatelessWidget {
  const TableroPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final productos = store.productos;
    final movimientos = store.movimientos;
    final al = alertas(productos);
    final valor = valorInventario(productos);
    final potencial = valorVentaPotencial(productos);
    final hoy = movimientosHoy(movimientos);
    final serie = serie7Dias(movimientos);
    final top = topProductos(movimientos);
    final cats = valorPorCategoria(productos);
    final abcRows = abc(productos);
    final muertos = stockMuerto(productos, movimientos);
    final maxSerie = [1, ...serie.expand((d) => [d.entradas, d.salidas])].reduce((a, b) => a > b ? a : b);
    final usados = store.negocio.reportesUsadosMes;
    final restantes = store.negocio.esPro ? null : (limiteReportesGratis - usados).clamp(0, limiteReportesGratis);

    void aviso(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }

    Future<void> bajar(String nombre, List<List<Object>> filas, {bool soloPro = false}) async {
      if (soloPro && !store.negocio.esPro) {
        aviso('Eso es de la versión Pro');
        return;
      }
      final ok = await ExportarService.exportar(
        context: context,
        store: store,
        nombreArchivo: nombre,
        filas: filas,
        soloPro: soloPro,
      );
      if (!context.mounted) return;
      if (!ok && !store.negocio.esPro && store.negocio.reportesUsadosMes >= limiteReportesGratis) {
        aviso('Tope de 2 descargas este mes. Pro las deja ilimitadas.');
        return;
      }
      if (ok) aviso('Excel listo. Elige WhatsApp, Drive o Excel para enviarlo o abrirlo.');
    }

    Future<void> bajarHistorial() async {
      RangoExport rango = RangoExport.todo;
      if (store.negocio.esPro) {
        final elegido = await showModalBottomSheet<RangoExport>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('¿De qué fechas es el historial?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('El Excel solo trae lo que entró, salió o se corrigió en ese tiempo.', style: TextStyle(color: R.muted)),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: R.forest),
                    onPressed: () => Navigator.pop(ctx, RangoExport.todo),
                    child: const Text('Todo'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.pop(ctx, RangoExport.mesActual()), child: const Text('Este mes')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.pop(ctx, RangoExport.semanaActual()), child: const Text('Esta semana')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final r = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(now.year - 3),
                        lastDate: DateTime(now.year, now.month, now.day),
                        helpText: 'Elige desde y hasta',
                        saveText: 'Usar estas fechas',
                      );
                      if (!ctx.mounted) return;
                      if (r == null) {
                        Navigator.pop(ctx);
                        return;
                      }
                      Navigator.pop(
                        ctx,
                        RangoExport(
                          desde: r.start,
                          hasta: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
                          etiqueta: 'Fechas',
                        ),
                      );
                    },
                    child: const Text('Elegir fechas en el calendario'),
                  ),
                ],
              ),
            ),
          ),
        );
        if (elegido == null) return;
        rango = elegido;
      }
      if (!movimientos.any((m) => rango.incluye(m.fecha))) {
        aviso('No hay movimientos en esas fechas');
        return;
      }
      final filas = ExportarService.filasHistorial(movimientos, store.negocio, rango);
      await bajar('historial-${slug(store.negocio.nombre)}-${rango.archivoSufijo}.xlsx', filas);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.negocio.nombre.trim().isEmpty ? 'Tu negocio' : store.negocio.nombre),
            if (store.negocio.nit.trim().isNotEmpty || store.negocio.direccion.trim().isNotEmpty)
              Text(
                [
                  if (store.negocio.nit.trim().isNotEmpty) 'NIT ${store.negocio.nit.trim()}',
                  if (store.negocio.direccion.trim().isNotEmpty) store.negocio.direccion.trim(),
                ].join(' · '),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: R.forest, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PLATA EN MERCANCÍA', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2)),
                Text(pesos(valor), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                Text('Si lo vendes todo: ${pesos(potencial)}', style: const TextStyle(color: Colors.white70)),
                if (store.negocio.nit.trim().isNotEmpty || store.negocio.direccion.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      [
                        if (store.negocio.nit.trim().isNotEmpty) 'NIT ${store.negocio.nit.trim()}',
                        if (store.negocio.direccion.trim().isNotEmpty) store.negocio.direccion.trim(),
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Kpi('Productos', '${productos.length}'),
              _Kpi('Hoy', '${hoy.length}'),
              _Kpi('Se acabaron', '${al.agotados.length}', color: al.agotados.isEmpty ? null : R.danger),
              _Kpi('Por acabarse', '${al.bajos.length}', color: al.bajos.isEmpty ? null : R.warn),
            ],
          ),
          if (al.agotados.isNotEmpty || al.bajos.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('HAY QUE REVISAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: R.muted)),
            ),
            Card(
              child: Column(
                children: [
                  for (final p in [...al.agotados, ...al.bajos])
                    ListTile(
                      leading: Icon(p.stockActual <= 0 ? Icons.remove_shopping_cart : Icons.warning_amber, color: p.stockActual <= 0 ? R.danger : R.warn),
                      title: Text(p.nombre),
                      subtitle: Text('${p.codigoRef} · ${p.stockActual} / mín. ${p.stockMinimo}'),
                      trailing: Text(p.stockActual <= 0 ? 'Se acabó' : 'Pocas', style: TextStyle(color: p.stockActual <= 0 ? R.danger : R.warn, fontWeight: FontWeight.w700)),
                      onTap: () => _abrirAjuste(context, store, p),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Entradas y salidas · 7 días', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in serie)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(child: Container(height: (d.entradas / maxSerie) * 90 + 4, color: R.ok)),
                                        const SizedBox(width: 2),
                                        Expanded(child: Container(height: (d.salidas / maxSerie) * 90 + 4, color: R.ink)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(d.etiqueta, style: const TextStyle(fontSize: 10, color: R.muted)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lo que más se vende', style: TextStyle(fontWeight: FontWeight.w700)),
                  if (top.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Aún no hay salidas.')),
                  for (final t in top)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(t.nombre, overflow: TextOverflow.ellipsis)),
                          Text('${t.unidades}', style: const TextStyle(color: R.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plata por categoría', style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(c.categoria)),
                          Text(pesos(c.valor), style: const TextStyle(color: R.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.negocio.esPro
                        ? 'Pro: Excel de verdad, eliges fechas, sin aviso.'
                        : '${restantes ?? 0} ${(restantes ?? 0) == 1 ? 'descarga' : 'descargas'} gratis este mes.',
                  ),
                  const SizedBox(height: 12),
                  const Text('Lista de productos', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Text('Un Excel con lo que hay ahora: cantidades, lo que te costó y a cómo lo vendes. Para mandarlo por WhatsApp, imprimirlo o abrirlo en el computador.', style: TextStyle(fontSize: 13, color: R.muted)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: R.forest, minimumSize: const Size.fromHeight(48)),
                    onPressed: () => bajar(
                      'productos-${slug(store.negocio.nombre)}-${fechaArchivo(DateTime.now())}.xlsx',
                      ExportarService.filasInventario(productos, store.negocio),
                    ),
                    icon: const Icon(Icons.download),
                    label: const Text('Descargar productos (Excel)'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Historial de movimientos', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    store.negocio.esPro
                        ? 'Un Excel de lo que entró y salió. Tú eliges: todo, este mes, esta semana o fechas del calendario.'
                        : 'Un Excel de lo que entró y salió. En Pro puedes elegir el mes, la semana o las fechas.',
                    style: const TextStyle(fontSize: 13, color: R.muted),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: bajarHistorial,
                    icon: const Icon(Icons.history),
                    label: const Text('Descargar historial (Excel)'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Contar lo del estante', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Text('Caminas el pasillo, escribes lo que ves y la app corrige las diferencias con lo que tenía registrado.', style: TextStyle(fontSize: 13, color: R.muted)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final seguir = await anuncioSiGratis(context, esPro: store.negocio.esPro);
                      if (!seguir || !context.mounted) return;
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ConteoPantalla()));
                    },
                    icon: const Icon(Icons.checklist),
                    label: const Text('Contar lo del estante'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1B4D3E),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Análisis de mercado Pro',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFFE08A), borderRadius: BorderRadius.circular(99)),
                        child: const Text('PRO', style: TextStyle(color: Color(0xFF5C3B00), fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Te dice en qué productos está la plata de la bodega, qué se vende y qué está parado. El nombre técnico es clasificación ABC; aquí te lo mostramos en cristiano.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  if (!store.negocio.esPro) ...[
                    const SizedBox(height: 12),
                    const Text('• A = lo que más vale (casi el 80% de tu plata)\n• B = lo del medio\n• C = lo barato, que no te distraiga\n• Parados = 14 días sin moverse', style: TextStyle(color: Colors.white, height: 1.45)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFE08A), foregroundColor: const Color(0xFF5C3B00)),
                        onPressed: () async {
                          final ok = await PlayBillingService.comprarLicenciaPro(context);
                          if (ok) await store.activarPro();
                        },
                        child: const Text('Ver mi análisis · Pro'),
                      ),
                    ),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 10, bottom: 8),
                      child: Text('A = aquí está casi toda la plata. B = intermedio. C = vale poco.', style: TextStyle(color: Colors.white70)),
                    ),
                    for (final r in abcRows.take(8))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: r.clase == 'A' ? R.ok : r.clase == 'B' ? R.warn : R.muted,
                          child: Text(r.clase, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                        title: Text(r.producto.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                        trailing: Text(pesos(r.valor), style: const TextStyle(color: Colors.white)),
                      ),
                    const Divider(color: Colors.white24),
                    const Text('Parados · 14 días sin movimiento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    if (muertos.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 8), child: Text('Nada parado esta quincena.', style: TextStyle(color: Colors.white70)))
                    else
                      for (final p in muertos)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.nombre, style: const TextStyle(color: Colors.white)),
                          trailing: Text('${p.stockActual} · ${pesos(p.stockActual * p.costo)}', style: const TextStyle(color: Colors.white70)),
                        ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.computer, color: R.forest),
              title: const Text('Úsala en el computador', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Pro: un QR y ves la bodega en la pantalla grande, en vivo.'),
              trailing: store.negocio.esPro
                  ? const Icon(Icons.chevron_right)
                  : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: R.pro, borderRadius: BorderRadius.circular(99)),
                child: const Text('Pro', style: TextStyle(color: R.proFg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EscritorioPantalla())),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirAjuste(BuildContext context, Store store, Producto p) {
    final stockNuevo = TextEditingController(text: '${p.stockActual}');
    final motivo = TextEditingController(text: 'Ajuste de conteo');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Corregir ${p.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cantidad en la app: ${p.stockActual}'),
            TextField(controller: stockNuevo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad real (estante)')),
            TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: R.forest),
            onPressed: () async {
              await store.ajustar(
                productoId: p.id!,
                stockNuevo: int.tryParse(stockNuevo.text) ?? 0,
                motivoAjuste: motivo.text.trim().isEmpty ? 'Ajuste de conteo' : motivo.text.trim(),
                referenciaAjuste: 'Tablero',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Kpi(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: R.muted)),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color ?? R.ink)),
            ],
          ),
        ),
      ),
    );
  }
}