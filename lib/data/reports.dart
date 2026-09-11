import '../models/types.dart';

enum NivelStock { ok, bajo, agotado }

NivelStock nivelStock(Producto p) {
  if (p.stockActual <= 0) return NivelStock.agotado;
  if (p.stockActual <= p.stockMinimo) return NivelStock.bajo;
  return NivelStock.ok;
}

double valorInventario(List<Producto> productos) =>
    productos.fold(0, (s, p) => s + p.stockActual * p.costo);

double valorVentaPotencial(List<Producto> productos) =>
    productos.fold(0, (s, p) => s + p.stockActual * p.precioVenta);

({List<Producto> agotados, List<Producto> bajos}) alertas(List<Producto> productos) {
  return (
  agotados: productos.where((p) => nivelStock(p) == NivelStock.agotado).toList(),
  bajos: productos.where((p) => nivelStock(p) == NivelStock.bajo).toList(),
  );
}

List<Movimiento> movimientosHoy(List<Movimiento> movimientos) {
  final hoy = DateTime.now();
  return movimientos.where((m) {
    final d = DateTime.tryParse(m.fecha);
    if (d == null) return false;
    return d.year == hoy.year && d.month == hoy.month && d.day == hoy.day;
  }).toList();
}

class DiaSerie {
  final String clave;
  final String etiqueta;
  int entradas;
  int salidas;
  DiaSerie(this.clave, this.etiqueta, {this.entradas = 0, this.salidas = 0});
}

List<DiaSerie> serie7Dias(List<Movimiento> movimientos) {
  const dias = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
  final days = <DiaSerie>[];
  for (var i = 6; i >= 0; i--) {
    final d = DateTime.now().subtract(Duration(days: i));
    final clave =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    days.add(DiaSerie(clave, dias[d.weekday % 7]));
  }
  for (final m in movimientos) {
    final dt = DateTime.tryParse(m.fecha);
    if (dt == null) continue;
    final clave =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final row = days.where((d) => d.clave == clave);
    if (row.isEmpty) continue;
    if (m.tipoMovimiento == 'ENTRADA') row.first.entradas += m.cantidad;
    if (m.tipoMovimiento == 'SALIDA') row.first.salidas += m.cantidad;
  }
  return days;
}

class TopItem {
  final String nombre;
  final int unidades;
  TopItem(this.nombre, this.unidades);
}

List<TopItem> topProductos(List<Movimiento> movimientos, [int limit = 5]) {
  final map = <int, TopItem>{};
  for (final m in movimientos) {
    if (m.tipoMovimiento != 'SALIDA') continue;
    final cur = map[m.productoId];
    map[m.productoId] = TopItem(m.productoNombre, (cur?.unidades ?? 0) + m.cantidad);
  }
  final list = map.values.toList()..sort((a, b) => b.unidades.compareTo(a.unidades));
  return list.take(limit).toList();
}

class CatValor {
  final String categoria;
  final double valor;
  CatValor(this.categoria, this.valor);
}

List<CatValor> valorPorCategoria(List<Producto> productos) {
  final map = <String, double>{};
  for (final p in productos) {
    map[p.categoria] = (map[p.categoria] ?? 0) + p.stockActual * p.costo;
  }
  final list = map.entries.map((e) => CatValor(e.key, e.value)).toList()
    ..sort((a, b) => b.valor.compareTo(a.valor));
  return list;
}

class AbcRow {
  final Producto producto;
  final double valor;
  final double pctAcum;
  final String clase;
  AbcRow(this.producto, this.valor, this.pctAcum, this.clase);
}

List<AbcRow> abc(List<Producto> productos) {
  final rows = productos.map((p) => (p, p.stockActual * p.costo)).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  final total = rows.fold<double>(0, (s, r) => s + r.$2);
  final den = total == 0 ? 1 : total;
  var acc = 0.0;
  return rows.map((r) {
    acc += r.$2;
    final pct = acc / den;
    final clase = pct <= 0.8 ? 'A' : pct <= 0.95 ? 'B' : 'C';
    return AbcRow(r.$1, r.$2, pct, clase);
  }).toList();
}

/// Stock con unidades y sin movimiento en [dias] días.
List<Producto> stockMuerto(
    List<Producto> productos,
    List<Movimiento> movimientos, [
      int dias = 14,
    ]) {
  final corte = DateTime.now().subtract(Duration(days: dias));
  final recientes = movimientos
      .where((m) {
    final d = DateTime.tryParse(m.fecha);
    return d != null && d.isAfter(corte);
  })
      .map((m) => m.productoId)
      .toSet();
  return productos.where((p) => p.stockActual > 0 && !recientes.contains(p.id)).toList();
}

double margenProducto(Producto p) {
  if (p.precioVenta <= 0) return 0;
  return (p.precioVenta - p.costo) / p.precioVenta;
}

/// Alias pedido por la pantalla vieja: no es rotación real.
@Deprecated('Usa stockMuerto()')
List<Producto> obtenerMercanciaEstancada(List<Producto> productos) {
  final lista = List<Producto>.from(productos);
  lista.sort((a, b) => a.stockActual.compareTo(b.stockActual));
  return lista;
}

Map<String, double> calcularValorInventario(List<Producto> productos) {
  return {
    'totalCosto': valorInventario(productos),
    'totalVenta': valorVentaPotencial(productos),
  };
}

class Reports {
  static Map<String, double> calcularValorInventario(List<Producto> productos) =>
      {
        'totalCosto': valorInventario(productos),
        'totalVenta': valorVentaPotencial(productos),
      };

  static List<Producto> obtenerMercanciaEstancada(List<Producto> productos) {
    final lista = List<Producto>.from(productos);
    lista.sort((a, b) => a.stockActual.compareTo(b.stockActual));
    return lista;
  }
}