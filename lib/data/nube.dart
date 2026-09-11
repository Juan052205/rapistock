import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/types.dart';
import 'nube_config.dart';

class Nube {
  static bool get lista {
    final db = kNubeDb.trim();
    final web = kNubeWeb.trim();
    return db.startsWith('https://') &&
        web.startsWith('https://') &&
        !db.contains('TU-PROYECTO') &&
        !web.contains('TU-SITIO');
  }

  static String enlacePc(String codigo) {
    final w = kNubeWeb.trim();
    final base = w.endsWith('/') ? w : '$w/';
    return '$base?k=${codigo.toUpperCase()}';
  }

  static String nuevoCodigo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Uri _uri(String codigo) =>
      Uri.parse('${kNubeDb.trim()}/sesiones/${codigo.toUpperCase()}.json');

  static Future<void> marcarCerrada(String codigo) async {
    if (!lista || codigo.isEmpty) return;
    try {
      final actual = await bajar(codigo) ?? <String, dynamic>{};
      actual['sesion'] = {
        'activa': false,
        'maxDispositivos': maxComputadores,
        'dispositivos': {},
      };
      actual['rev'] = DateTime.now().millisecondsSinceEpoch;
      await http.put(
        _uri(codigo),
        body: jsonEncode(actual),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Nube.marcarCerrada: $e');
    }
  }

  static Future<void> subir({
    required String codigo,
    required Negocio negocio,
    required List<Producto> productos,
    required List<Movimiento> movimientos,
    Map<String, String> categoriasExtra = const {},
    List<Cliente> clientes = const [],
    int historialReset = 0,
    bool sesionActiva = true,
    List<DispositivoNube>? dispositivos,
  }) async {
    if (!lista || codigo.isEmpty) return;
    try {
      Map<String, dynamic> devs = {};
      final actual = await bajar(codigo);
      if (actual != null) {
        final ses = actual['sesion'];
        if (ses is Map && ses['dispositivos'] is Map) {
          devs = Map<String, dynamic>.from(ses['dispositivos'] as Map);
        }
      }
      if (dispositivos != null) {
        devs = {
          for (final d in dispositivos) d.id: {'nombre': d.nombre, 'lastSeen': d.lastSeen},
        };
      }

      final body = jsonEncode({
        'rev': DateTime.now().millisecondsSinceEpoch,
        'negocio': {
          'nombre': negocio.nombre,
          'nit': negocio.nit,
          'direccion': negocio.direccion,
          'esPro': negocio.esPro,
          'permitirStockNegativo': negocio.permitirStockNegativo,
        },
        'sesion': {
          'activa': sesionActiva,
          'maxDispositivos': maxComputadores,
          'dispositivos': devs,
        },
        'categoriasExtra': categoriasExtra,
        'historialReset': historialReset,
        'clientes': [
          for (final c in clientes)
            {
              'id': c.id,
              'nombre': c.nombre,
              'telefono': c.telefono,
              'nit': c.nit,
              'direccion': c.direccion,
            },
        ],
        'productos': [
          for (final p in productos)
            {
              'id': p.id,
              'codigoRef': p.codigoRef,
              'nombre': p.nombre,
              'categoria': p.categoria,
              'unidad': p.unidad,
              'stockActual': p.stockActual,
              'stockMinimo': p.stockMinimo,
              'costo': p.costo,
              'precioVenta': p.precioVenta,
              'proveedor': p.proveedor,
              'ubicacion': p.ubicacion,
            },
        ],
        'movimientos': [
          for (final m in movimientos.take(500))
            {
              'id': m.id,
              'productoId': m.productoId,
              'productoNombre': m.productoNombre,
              'codigoRef': m.codigoRef,
              'tipoMovimiento': m.tipoMovimiento,
              'cantidad': m.cantidad,
              'stockAntes': m.stockAntes,
              'stockDespues': m.stockDespues,
              'motivo': m.motivo,
              'referencia': m.referencia,
              'fecha': m.fecha,
              'clienteId': m.clienteId,
              'clienteNombre': m.clienteNombre,
            },
        ],
      });
      final r = await http.put(
        _uri(codigo),
        body: body,
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode >= 300) {
        debugPrint('Nube.subir ${r.statusCode} ${r.body}');
      }
    } catch (e) {
      debugPrint('Nube.subir: $e');
    }
  }

  static Future<Map<String, dynamic>?> bajar(String codigo) async {
    if (!lista || codigo.isEmpty) return null;
    try {
      final r = await http.get(_uri(codigo));
      if (r.statusCode != 200 || r.body == 'null' || r.body.isEmpty) return null;
      final data = jsonDecode(r.body);
      if (data is Map<String, dynamic>) return data;
    } catch (e) {
      debugPrint('Nube.bajar: $e');
    }
    return null;
  }
}