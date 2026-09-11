import 'package:sqflite/sqflite.dart';
import '../models/types.dart';

const demoNombre = 'Tienda El Barrio';
const demoNit = '901.234.567-8';
const demoDireccion = 'Calle 10 #5-20, Centro';

Future<void> seedDemo(Database db) async {
  final productos = seedProductos();
  final ids = <String, int>{};
  for (final p in productos) {
    final id = await db.insert('productos', p.toMap());
    ids[p.codigoRef] = id;
  }

  Future<void> mv({
    required String codigo,
    required String tipo,
    required int cantidad,
    required int antes,
    required String motivo,
    required String fecha,
    required String referencia,
    double? costo,
  }) async {
    final p = productos.firstWhere((x) => x.codigoRef == codigo);
    final despues = tipo == 'ENTRADA' ? antes + cantidad : antes - cantidad;
    await db.insert('movimientos', {
      'producto_id': ids[codigo],
      'producto_nombre': p.nombre,
      'codigo_ref': codigo,
      'tipo_movimiento': tipo,
      'cantidad': cantidad,
      'stock_antes': antes,
      'stock_despues': despues,
      'costo_historico': costo ?? p.costo,
      'motivo': motivo,
      'referencia': referencia,
      'fecha': fecha,
      'lote_id': 'seed',
    });
  }

  String d(int n, [int h = 10]) {
    final x = DateTime.now().subtract(Duration(days: n));
    return DateTime(x.year, x.month, x.day, h, 12).toIso8601String();
  }

  await mv(codigo: 'ME-002', tipo: 'ENTRADA', cantidad: 12, antes: 6, motivo: 'Compra a proveedor', fecha: d(6, 9), referencia: 'FC-1830');
  await mv(codigo: 'ME-001', tipo: 'ENTRADA', cantidad: 24, antes: 24, motivo: 'Compra a proveedor', fecha: d(6, 9), referencia: 'FC-1830');
  await mv(codigo: 'ME-001', tipo: 'SALIDA', cantidad: 3, antes: 51, motivo: 'Venta', fecha: d(5, 11), referencia: 'V-2188');
  await mv(codigo: 'ME-003', tipo: 'SALIDA', cantidad: 4, antes: 10, motivo: 'Venta', fecha: d(4, 16), referencia: 'V-2190');
  await mv(codigo: 'AS-001', tipo: 'SALIDA', cantidad: 8, antes: 10, motivo: 'Venta', fecha: d(3, 12), referencia: 'V-2194');
  await mv(codigo: 'ME-008', tipo: 'SALIDA', cantidad: 8, antes: 8, motivo: 'Venta', fecha: d(2, 18), referencia: 'V-2199');
  await mv(codigo: 'LA-001', tipo: 'SALIDA', cantidad: 7, antes: 16, motivo: 'Venta', fecha: d(1, 9), referencia: 'V-2204');
  await mv(codigo: 'BE-001', tipo: 'SALIDA', cantidad: 6, antes: 42, motivo: 'Venta', fecha: d(0, 8), referencia: 'V-2210');
}

List<Producto> seedProductos() => const [
  Producto(codigoRef: 'ME-001', nombre: 'Arroz Diana 500 g', categoria: 'Mercado', unidad: 'und', stockActual: 48, stockMinimo: 12, costo: 1800, precioVenta: 2500, proveedor: 'Distribuidora El Sol', ubicacion: 'Pasillo 1'),
  Producto(codigoRef: 'ME-002', nombre: 'Aceite Premier 1 L', categoria: 'Mercado', unidad: 'und', stockActual: 18, stockMinimo: 8, costo: 8900, precioVenta: 11900, proveedor: 'Distribuidora El Sol', ubicacion: 'Pasillo 1'),
  Producto(codigoRef: 'ME-003', nombre: 'Azúcar Incauca 1 kg', categoria: 'Mercado', unidad: 'und', stockActual: 6, stockMinimo: 10, costo: 3200, precioVenta: 4200, proveedor: 'Distribuidora El Sol', ubicacion: 'Pasillo 1'),
  Producto(codigoRef: 'ME-004', nombre: 'Café Sello Rojo 250 g', categoria: 'Mercado', unidad: 'und', stockActual: 22, stockMinimo: 8, costo: 7800, precioVenta: 10500, proveedor: 'Café y Granos SAS', ubicacion: 'Pasillo 2'),
  Producto(codigoRef: 'ME-005', nombre: 'Panela cuadrada 500 g', categoria: 'Mercado', unidad: 'und', stockActual: 31, stockMinimo: 10, costo: 2100, precioVenta: 3000, proveedor: 'Café y Granos SAS', ubicacion: 'Pasillo 2'),
  Producto(codigoRef: 'LA-001', nombre: 'Leche Alquería 1 L', categoria: 'Lácteos', unidad: 'lt', stockActual: 9, stockMinimo: 16, costo: 3800, precioVenta: 4900, proveedor: 'Lácteos del Valle', ubicacion: 'Nevera'),
  Producto(codigoRef: 'LA-002', nombre: 'Huevos AA x30', categoria: 'Lácteos', unidad: 'paq', stockActual: 14, stockMinimo: 6, costo: 14500, precioVenta: 17900, proveedor: 'Granja La Esperanza', ubicacion: 'Nevera'),
  Producto(codigoRef: 'ME-006', nombre: 'Harina P.A.N. 1 kg', categoria: 'Mercado', unidad: 'und', stockActual: 27, stockMinimo: 8, costo: 4200, precioVenta: 5600, proveedor: 'Distribuidora El Sol', ubicacion: 'Pasillo 1'),
  Producto(codigoRef: 'ME-007', nombre: 'Atún Van Camps 160 g', categoria: 'Mercado', unidad: 'und', stockActual: 40, stockMinimo: 12, costo: 4500, precioVenta: 6200, proveedor: 'Distribuidora El Sol', ubicacion: 'Pasillo 3'),
  Producto(codigoRef: 'AS-001', nombre: 'Jabón Rey barra', categoria: 'Aseo', unidad: 'und', stockActual: 2, stockMinimo: 10, costo: 1800, precioVenta: 2500, proveedor: 'Aseo Total', ubicacion: 'Pasillo 4'),
  Producto(codigoRef: 'AS-002', nombre: 'Papel higiénico Familia x4', categoria: 'Aseo', unidad: 'paq', stockActual: 11, stockMinimo: 6, costo: 8900, precioVenta: 11900, proveedor: 'Aseo Total', ubicacion: 'Pasillo 4'),
  Producto(codigoRef: 'BE-001', nombre: 'Gaseosa Postobón 1.5 L', categoria: 'Bebidas', unidad: 'und', stockActual: 36, stockMinimo: 12, costo: 3200, precioVenta: 4500, proveedor: 'Bebidas del Centro', ubicacion: 'Bodega'),
  Producto(codigoRef: 'BE-002', nombre: 'Cerveza Poker x6', categoria: 'Bebidas', unidad: 'paq', stockActual: 8, stockMinimo: 8, costo: 14500, precioVenta: 18900, proveedor: 'Bebidas del Centro', ubicacion: 'Nevera'),
  Producto(codigoRef: 'ME-008', nombre: 'Sal Refisal 1 kg', categoria: 'Mercado', unidad: 'und', stockActual: 0, stockMinimo: 8, costo: 1400, precioVenta: 2000, proveedor: 'Distribuidora El Sol', ubicacion: 'Pasillo 1'),
];