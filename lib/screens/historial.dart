import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/exportar.dart';
import '../data/format.dart';
import '../data/store.dart';
import '../models/types.dart';
import '../theme.dart';

class HistorialPantalla extends StatefulWidget {
  const HistorialPantalla({super.key});

  @override
  State<HistorialPantalla> createState() => _HistorialPantallaState();
}

class _HistorialPantallaState extends State<HistorialPantalla> {
  String q = '';
  String tipo = 'todos';
  String rango = 'todos';
  String clienteF = '';
  String productoF = '';
  DateTime? desde;
  DateTime? hasta;

  bool _enRango(String fechaIso) {
    if (rango == 'todos') return true;
    final d = DateTime.tryParse(fechaIso);
    if (d == null) return false;
    final n = DateTime.now();
    DateTime a;
    DateTime b;
    if (rango == 'hoy') {
      a = DateTime(n.year, n.month, n.day);
      b = DateTime(n.year, n.month, n.day, 23, 59, 59);
    } else if (rango == 'semana') {
      a = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
      b = a.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else if (rango == 'mes') {
      a = DateTime(n.year, n.month, 1);
      b = DateTime(n.year, n.month + 1, 0, 23, 59, 59);
    } else {
      if (desde == null || hasta == null) return true;
      a = DateTime(desde!.year, desde!.month, desde!.day);
      b = DateTime(hasta!.year, hasta!.month, hasta!.day, 23, 59, 59);
    }
    return !d.isBefore(a) && !d.isAfter(b);
  }

  Future<void> _elegirFechas() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Elige desde y hasta',
      saveText: 'Ver estas fechas',
    );
    if (r == null || !mounted) return;
    setState(() {
      rango = 'fechas';
      desde = r.start;
      hasta = r.end;
    });
  }

  Future<void> _limpiar(Store store) async {
    final ir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Guardar Excel y limpiar el historial?'),
        content: const Text(
          'Primero te descargo un Excel con TODO lo que hay hasta hoy. '
              'Después se vacía el listado de Historial y las barras de 7 días del Tablero vuelven a cero.\n\n'
              'Los productos y las cantidades de la bodega NO se tocan. '
              'El Excel queda en tu teléfono para que no pierdas nada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: R.forest),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descargar y limpiar'),
          ),
        ],
      ),
    );
    if (ir != true || !mounted) return;
    final ok = await ExportarService.exportar(
      context: context,
      store: store,
      nombreArchivo: 'historial-${slug(store.negocio.nombre)}-respaldo-${fechaArchivo(DateTime.now())}.xlsx',
      filas: ExportarService.filasHistorial(store.movimientos, store.negocio),
      contarComoReporte: false,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pude armar el Excel. El historial se quedó igual.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final r = await store.vaciarHistorial();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.ok
            ? 'Historial limpio. El Excel de respaldo ya está listo.'
            : 'El Excel salió, pero no pude limpiar. Intenta de nuevo.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );

  Widget _chip(String id, String label, String sel, ValueChanged<String> onTap) {
    final on = sel == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: on,
        selectedColor: R.forest,
        labelStyle: TextStyle(color: on ? Colors.white : R.ink, fontSize: 12),
        onSelected: (_) => onTap(id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final n = q.trim().toLowerCase();

    final clientesNombres = <String>{
      for (final c in store.clientes) c.nombre.trim(),
      for (final m in store.movimientos)
        if (m.clienteNombre.trim().isNotEmpty) m.clienteNombre.trim(),
    }.where((e) => e.isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final productosNombres = <String>{
      for (final p in store.productos) p.nombre.trim(),
      for (final m in store.movimientos) m.productoNombre.trim(),
    }.where((e) => e.isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final clienteOk = clienteF == '' || clienteF == '__mostrador__' || clientesNombres.contains(clienteF);
    final productoOk = productoF == '' || productosNombres.contains(productoF);
    final clienteSel = clienteOk ? clienteF : '';
    final productoSel = productoOk ? productoF : '';

    final lista = store.movimientos.where((m) {
      if (tipo != 'todos' && m.tipoMovimiento != tipo) return false;
      if (!_enRango(m.fecha)) return false;
      if (clienteSel == '__mostrador__') {
        if (m.tipoMovimiento != 'SALIDA' || m.clienteNombre.trim().isNotEmpty) return false;
      } else if (clienteSel.isNotEmpty) {
        if (m.clienteNombre.trim().toLowerCase() != clienteSel.toLowerCase()) return false;
      }
      if (productoSel.isNotEmpty && m.productoNombre.trim() != productoSel) return false;
      if (n.isEmpty) return true;
      return m.productoNombre.toLowerCase().contains(n) ||
          m.codigoRef.toLowerCase().contains(n) ||
          m.motivo.toLowerCase().contains(n) ||
          m.referencia.toLowerCase().contains(n) ||
          m.clienteNombre.toLowerCase().contains(n);
    }).toList();

    String resumen = '';
    if (lista.isNotEmpty) {
      if (productoSel.isNotEmpty) {
        var sal = 0;
        var ent = 0;
        for (final m in lista) {
          if (m.tipoMovimiento == 'SALIDA') sal += m.cantidad;
          if (m.tipoMovimiento == 'ENTRADA') ent += m.cantidad;
        }
        resumen = '$productoSel · ${lista.length} mov. · salió $sal · entró $ent';
      } else if (clienteSel.isNotEmpty) {
        final quien = clienteSel == '__mostrador__' ? 'Mostrador' : clienteSel;
        resumen = '$quien · ${lista.length} movimientos';
      } else {
        final cnt = <String, int>{};
        for (final m in lista) {
          cnt[m.productoNombre] = (cnt[m.productoNombre] ?? 0) + 1;
        }
        final top = cnt.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final t = top.take(3).map((e) => '${e.key} (${e.value})').join(' · ');
        if (t.isNotEmpty) resumen = 'Más se movió: $t';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Historial · ${store.movimientos.length}'),
        actions: [
          if (store.movimientos.isNotEmpty)
            IconButton(
              tooltip: 'Guardar Excel y limpiar',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () => _limpiar(store),
            ),
        ],
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Código o factura...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => q = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('cli-$clienteSel'),
                          initialValue: clienteSel,
                          isExpanded: true,
                          decoration: _deco('Cliente'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Todos', overflow: TextOverflow.ellipsis)),
                            const DropdownMenuItem(value: '__mostrador__', child: Text('Mostrador', overflow: TextOverflow.ellipsis)),
                            ...clientesNombres.map(
                                  (c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                            ),
                          ],
                          onChanged: (v) => setState(() => clienteF = v ?? ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('prod-$productoSel'),
                          initialValue: productoSel,
                          isExpanded: true,
                          decoration: _deco('Producto'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Todos', overflow: TextOverflow.ellipsis)),
                            ...productosNombres.map(
                                  (p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)),
                            ),
                          ],
                          onChanged: (v) => setState(() => productoF = v ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('todos', 'Todos', rango, (id) => setState(() => rango = id)),
                        _chip('hoy', 'Hoy', rango, (id) => setState(() => rango = id)),
                        _chip('semana', 'Semana', rango, (id) => setState(() => rango = id)),
                        _chip('mes', 'Este mes', rango, (id) => setState(() => rango = id)),
                        _chip(
                          'fechas',
                          rango == 'fechas' && desde != null && hasta != null
                              ? '${fechaArchivo(desde!)} → ${fechaArchivo(hasta!)}'
                              : 'Fechas',
                          rango,
                              (_) => _elegirFechas(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('todos', 'Todos', tipo, (id) => setState(() => tipo = id)),
                        _chip('ENTRADA', 'Entró', tipo, (id) => setState(() => tipo = id)),
                        _chip('SALIDA', 'Salió', tipo, (id) => setState(() => tipo = id)),
                        _chip('AJUSTE', 'Correcciones', tipo, (id) => setState(() => tipo = id)),
                      ],
                    ),
                  ),
                  if (resumen.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(resumen, style: const TextStyle(fontSize: 12, color: R.forest, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
          if (lista.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No hay movimientos en este filtro.')),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 16 + MediaQuery.viewPaddingOf(context).bottom),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final m = lista[i];
                    final esEntrada = m.tipoMovimiento == 'ENTRADA';
                    final esSalida = m.tipoMovimiento == 'SALIDA';
                    final color = esEntrada ? R.ok : esSalida ? R.danger : R.warn;
                    final etiqueta = esEntrada ? 'Entró' : esSalida ? 'Salió' : 'Corrección';
                    final aQuien = esSalida
                        ? (m.clienteNombre.trim().isEmpty ? 'Mostrador' : m.clienteNombre.trim())
                        : '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          esEntrada ? Icons.arrow_downward : esSalida ? Icons.arrow_upward : Icons.tune,
                          color: color,
                        ),
                        title: Text(m.productoNombre, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '$etiqueta · ${m.codigoRef}'
                              '${aQuien.isNotEmpty ? ' · $aQuien' : ''}'
                              '${m.referencia.isNotEmpty ? ' · ${m.referencia}' : ''}'
                              '${m.motivo.isNotEmpty ? ' · ${m.motivo}' : ''}\n'
                              'Antes ${m.stockAntes} → ahora ${m.stockDespues} · ${fechaCorta(m.fecha)}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          '${esSalida ? '−' : esEntrada ? '+' : '±'}${m.cantidad}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                        ),
                      ),
                    );
                  },
                  childCount: lista.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}