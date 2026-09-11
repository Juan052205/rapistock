import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/types.dart';
import 'database_helper.dart';
import 'format.dart';
import 'nube.dart';
import 'seed.dart';

class Store extends ChangeNotifier {
  List<Producto> productos = [];
  List<Movimiento> movimientos = [];
  List<Cliente> clientes = [];
  List<DispositivoNube> dispositivosNube = [];
  Cliente? clienteVenta;
  Negocio negocio = Negocio(
    nombre: '',
    nit: '',
    direccion: '',
    esPro: false,
    reportesUsadosMes: 0,
    mesReportes: mesClave(),
    permitirStockNegativo: false,
    esDemo: false,
    codigoNube: '',
  );
  bool isLoading = true;
  String? errorCarga;

  String tipoCarrito = 'ENTRADA';
  List<CarritoItem> carrito = [];
  String motivo = 'Compra a proveedor';
  String referencia = '';
  String proveedorDoc = '';
  Map<String, String> categoriasExtra = {};

  Timer? _nubeTick;
  int _revNube = 0;
  int _historialReset = 0;
  bool _aplicandoNube = false;

  bool get esProLicencia => negocio.esPro;
  bool get tieneCarritoPendiente => carrito.isNotEmpty;

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> cargarProductos() async {
    isLoading = true;
    errorCarga = null;
    notifyListeners();
    try {
      final db = await _db;
      await DatabaseHelper.instance.ensureSchema(db);
      await _cargarNegocio(db);
      List<Map<String, dynamic>> rows;
      try {
        rows = await db.query('productos', where: 'activo = 1', orderBy: 'nombre COLLATE NOCASE');
      } catch (_) {
        rows = await db.query('productos', orderBy: 'nombre COLLATE NOCASE');
      }
      productos = rows.map(Producto.fromMap).toList();
      final mv = await db.query('movimientos', orderBy: 'id DESC');
      movimientos = mv.map(Movimiento.fromMap).toList();
      await _cargarCategorias(db);
      await _cargarClientes(db);
    } catch (e, st) {
      errorCarga = 'No pude abrir la bodega. Cierra la app y ábrela de nuevo.';
      debugPrint('cargarProductos: $e\n$st');
    } finally {
      isLoading = false;
      notifyListeners();
      _arrancarNube();
      if (!_aplicandoNube) unawaited(_subirNube());
    }
  }

  Future<void> _cargarClientes(Database db) async {
    try {
      final rows = await db.query('clientes', where: 'activo = 1', orderBy: 'nombre COLLATE NOCASE');
      clientes = rows.map(Cliente.fromMap).toList();
    } catch (e) {
      debugPrint('_cargarClientes: $e');
      clientes = [];
    }
  }

  void _arrancarNube() {
    if (!Nube.lista || negocio.codigoNube.isEmpty) return;
    _nubeTick ??= Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_bajarNube());
    });
  }

  Future<void> activarEscritorioNube() async {
    var code = negocio.codigoNube.trim();
    if (code.isEmpty) {
      code = Nube.nuevoCodigo();
      await guardarNegocio(negocio.copyWith(codigoNube: code));
    }
    _arrancarNube();
    await _subirNube();
  }

  Future<void> cerrarComputadores() async {
    final viejo = negocio.codigoNube.trim();
    if (viejo.isNotEmpty) {
      await Nube.marcarCerrada(viejo);
    }
    final nuevo = Nube.nuevoCodigo();
    dispositivosNube = [];
    await guardarNegocio(negocio.copyWith(codigoNube: nuevo));
    await _subirNube();
  }

  Future<void> quitarDispositivo(String id) async {
    dispositivosNube = dispositivosNube.where((d) => d.id != id).toList();
    notifyListeners();
    await _subirNube(forzarDispositivos: true);
  }

  Future<void> _subirNube({bool forzarDispositivos = false}) async {
    if (!Nube.lista || negocio.codigoNube.isEmpty) return;
    await Nube.subir(
      codigo: negocio.codigoNube,
      negocio: negocio,
      productos: productos,
      movimientos: movimientos,
      categoriasExtra: categoriasExtra,
      clientes: clientes,
      historialReset: _historialReset,
      sesionActiva: true,
      dispositivos: forzarDispositivos ? dispositivosNube : null,
    );
  }

  Future<void> _bajarNube() async {
    if (_aplicandoNube || negocio.codigoNube.isEmpty) return;
    final data = await Nube.bajar(negocio.codigoNube);
    if (data == null) return;
    final rev = (data['rev'] as num?)?.toInt() ?? 0;
    final ses = data['sesion'];
    if (ses is Map) {
      final rawDevs = ses['dispositivos'];
      if (rawDevs is Map) {
        dispositivosNube = rawDevs.entries.map((e) {
          final m = e.value is Map ? Map<String, dynamic>.from(e.value as Map) : <String, dynamic>{};
          return DispositivoNube(
            id: '${e.key}',
            nombre: '${m['nombre'] ?? 'Computador'}',
            lastSeen: (m['lastSeen'] as num?)?.toInt() ?? 0,
          );
        }).toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      }
    }
    if (rev <= _revNube) {
      notifyListeners();
      return;
    }
    _aplicandoNube = true;
    try {
      final db = await _db;
      await DatabaseHelper.instance.ensureSchema(db);

      final reset = (data['historialReset'] as num?)?.toInt() ?? 0;
      if (reset > _historialReset) {
        await db.delete('movimientos');
        _historialReset = reset;
      }

      final neg = data['negocio'];
      if (neg is Map) {
        final m = Map<String, dynamic>.from(neg);
        await db.update(
          'negocio',
          {
            'nombre': '${m['nombre'] ?? negocio.nombre}',
            'nit': '${m['nit'] ?? negocio.nit}',
            'direccion': '${m['direccion'] ?? negocio.direccion}',
            'permitir_stock_negativo': (m['permitirStockNegativo'] == true) ? 1 : 0,
          },
          where: 'id = 1',
        );
      }

      final cats = data['categoriasExtra'];
      if (cats is Map) {
        for (final e in cats.entries) {
          try {
            await db.insert(
              'categorias',
              {'nombre': '${e.key}', 'prefijo': '${e.value}'},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          } catch (_) {}
        }
      }

      final cls = data['clientes'];
      if (cls is List) {
        for (final raw in cls) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final nom = '${m['nombre'] ?? ''}'.trim();
          if (nom.isEmpty) continue;
          final exist = await db.query('clientes', where: 'nombre = ? AND activo = 1', whereArgs: [nom], limit: 1);
          final row = {
            'nombre': nom,
            'telefono': '${m['telefono'] ?? ''}',
            'nit': '${m['nit'] ?? ''}',
            'direccion': '${m['direccion'] ?? ''}',
            'activo': 1,
          };
          if (exist.isEmpty) {
            await db.insert('clientes', row);
          } else {
            await db.update('clientes', row, where: 'id = ?', whereArgs: [exist.first['id']]);
          }
        }
      }

      final prods = data['productos'];
      final refsNube = <String>{};
      if (prods is List) {
        for (final raw in prods) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final ref = '${m['codigoRef'] ?? ''}';
          if (ref.isEmpty) continue;
          refsNube.add(ref);
          final row = {
            'codigo_ref': ref,
            'nombre': '${m['nombre'] ?? ''}',
            'categoria': categoriaAmigable('${m['categoria'] ?? 'Mercado'}'),
            'unidad': '${m['unidad'] ?? 'und'}',
            'stock_actual': (m['stockActual'] as num?)?.toInt() ?? 0,
            'stock_minimo': (m['stockMinimo'] as num?)?.toInt() ?? 10,
            'costo': (m['costo'] as num?)?.toDouble() ?? 0,
            'precio_venta': (m['precioVenta'] as num?)?.toDouble() ?? 0,
            'proveedor': '${m['proveedor'] ?? ''}',
            'ubicacion': '${m['ubicacion'] ?? ''}',
            'activo': 1,
          };
          final exist = await db.query('productos', where: 'codigo_ref = ?', whereArgs: [ref], limit: 1);
          if (exist.isEmpty) {
            await db.insert('productos', row);
          } else {
            await db.update('productos', row, where: 'codigo_ref = ?', whereArgs: [ref]);
          }
        }
      }

      if (refsNube.isNotEmpty) {
        final locales = await db.query('productos', columns: ['id', 'codigo_ref', 'activo']);
        for (final r in locales) {
          final ref = '${r['codigo_ref']}';
          if (!refsNube.contains(ref) && ((r['activo'] as num?)?.toInt() ?? 1) == 1) {
            await db.update('productos', {'activo': 0}, where: 'id = ?', whereArgs: [r['id']]);
          }
        }
      }

      final idPorRef = <String, int>{};
      for (final r in await db.query('productos', columns: ['id', 'codigo_ref'])) {
        idPorRef['${r['codigo_ref']}'] = (r['id'] as num).toInt();
      }

      final movs = data['movimientos'];
      if (movs is List) {
        for (final raw in movs) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final ref = '${m['codigoRef'] ?? ''}';
          final fecha = '${m['fecha'] ?? ''}';
          final tipo = '${m['tipoMovimiento'] ?? ''}';
          final cant = (m['cantidad'] as num?)?.toInt() ?? 0;
          if (ref.isEmpty || fecha.isEmpty) continue;
          final dup = await db.query(
            'movimientos',
            where: 'codigo_ref = ? AND fecha = ? AND tipo_movimiento = ? AND cantidad = ?',
            whereArgs: [ref, fecha, tipo, cant],
            limit: 1,
          );
          if (dup.isNotEmpty) continue;
          await db.insert('movimientos', {
            'producto_id': idPorRef[ref] ?? (m['productoId'] as num?)?.toInt() ?? 0,
            'producto_nombre': '${m['productoNombre'] ?? ''}',
            'codigo_ref': ref,
            'tipo_movimiento': tipo,
            'cantidad': cant,
            'stock_antes': (m['stockAntes'] as num?)?.toInt() ?? 0,
            'stock_despues': (m['stockDespues'] as num?)?.toInt() ?? 0,
            'costo_historico': 0,
            'motivo': '${m['motivo'] ?? ''}',
            'referencia': '${m['referencia'] ?? ''}',
            'fecha': fecha,
            'lote_id': 'nube',
            'cliente_id': (m['clienteId'] as num?)?.toInt(),
            'cliente_nombre': '${m['clienteNombre'] ?? ''}',
          });
        }
      }

      _revNube = rev;
      await cargarProductos();
    } catch (e) {
      debugPrint('_bajarNube: $e');
    } finally {
      _aplicandoNube = false;
    }
  }

  Future<void> _cargarNegocio(Database db) async {
    final rows = await db.query('negocio', where: 'id = 1');
    if (rows.isEmpty) return;
    final r = rows.first;
    var mes = (r['mes_reportes'] as String?) ?? '';
    var usados = (r['reportes_mes'] as num?)?.toInt() ?? 0;
    final ahora = mesClave();
    if (mes != ahora) {
      mes = ahora;
      usados = 0;
      await db.update('negocio', {'mes_reportes': mes, 'reportes_mes': 0}, where: 'id = 1');
    }
    negocio = Negocio(
      nombre: (r['nombre'] as String?) ?? '',
      nit: (r['nit'] as String?) ?? '',
      direccion: (r['direccion'] as String?) ?? '',
      esPro: ((r['es_pro'] as num?)?.toInt() ?? 0) == 1,
      reportesUsadosMes: usados,
      mesReportes: mes,
      permitirStockNegativo: ((r['permitir_stock_negativo'] as num?)?.toInt() ?? 0) == 1,
      esDemo: ((r['es_demo'] as num?)?.toInt() ?? 0) == 1,
      codigoNube: (r['codigo_nube'] as String?) ?? '',
    );
  }

  Future<void> _cargarCategorias(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categorias (
          nombre TEXT PRIMARY KEY,
          prefijo TEXT NOT NULL UNIQUE
        )
      ''');
      final rows = await db.query('categorias', orderBy: 'nombre COLLATE NOCASE');
      categoriasExtra = {
        for (final r in rows) (r['nombre'] as String): (r['prefijo'] as String),
      };
    } catch (e) {
      debugPrint('_cargarCategorias: $e');
      categoriasExtra = {};
    }
  }

  List<String> get categoriasTodas {
    final lista = [...categorias];
    for (final n in categoriasExtra.keys) {
      if (!lista.any((c) => c.toLowerCase() == n.toLowerCase())) lista.add(n);
    }
    return lista;
  }

  Set<String> get _prefijosUsados => {...prefijoCategoria.values, ...categoriasExtra.values};

  String prefijoDe(String categoria) {
    if (prefijoCategoria.containsKey(categoria)) return prefijoCategoria[categoria]!;
    final extra = categoriasExtra[categoria];
    if (extra != null) return extra;
    return generarPrefijo(categoria, _prefijosUsados);
  }

  String codigoSiguiente(String categoria) => siguienteCodigoDe(productos, prefijoDe(categoria));

  Future<Resultado> crearCategoria(String nombre) async {
    final n = nombre.trim();
    if (n.isEmpty) return const Resultado(ok: false, reason: 'vacio');
    final existe = categoriasTodas.any((c) => c.toLowerCase() == n.toLowerCase());
    if (existe) return const Resultado(ok: false, reason: 'existe');
    final pref = generarPrefijo(n, _prefijosUsados);
    try {
      final db = await _db;
      await _cargarCategorias(db);
      await db.insert('categorias', {'nombre': n, 'prefijo': pref});
      categoriasExtra[n] = pref;
      notifyListeners();
      return Resultado(ok: true, codigoRef: pref);
    } catch (e) {
      debugPrint('crearCategoria: $e');
      return const Resultado(ok: false, reason: 'db');
    }
  }

  Future<Resultado> eliminarCategoria(String nombre) async {
    final n = nombre.trim();
    if (n.isEmpty) return const Resultado(ok: false, reason: 'vacio');
    if (prefijoCategoria.containsKey(n)) return const Resultado(ok: false, reason: 'fabrica');
    try {
      final db = await _db;
      await _cargarCategorias(db);
      await db.delete('categorias', where: 'nombre = ?', whereArgs: [n]);
      categoriasExtra.removeWhere((k, _) => k.toLowerCase() == n.toLowerCase());
      notifyListeners();
      return const Resultado(ok: true);
    } catch (e) {
      debugPrint('eliminarCategoria: $e');
      return const Resultado(ok: false, reason: 'db');
    }
  }

  Future<Resultado> agregarCliente(Cliente c) async {
    if (!negocio.esPro && clientes.length >= limiteClientesGratis) {
      return const Resultado(ok: false, reason: 'limite');
    }
    try {
      final db = await _db;
      await db.insert('clientes', c.toMap());
      await cargarProductos();
      return const Resultado(ok: true);
    } catch (e) {
      debugPrint('agregarCliente: $e');
      return const Resultado(ok: false, reason: 'db');
    }
  }

  Future<Resultado> actualizarCliente(Cliente c) async {
    if (c.id == null) return const Resultado(ok: false, reason: 'id');
    try {
      final db = await _db;
      await db.update('clientes', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
      if (clienteVenta?.id == c.id) clienteVenta = c;
      await cargarProductos();
      return const Resultado(ok: true);
    } catch (e) {
      debugPrint('actualizarCliente: $e');
      return const Resultado(ok: false, reason: 'db');
    }
  }

  Future<void> eliminarCliente(int id) async {
    final db = await _db;
    await db.update('clientes', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
    if (clienteVenta?.id == id) clienteVenta = null;
    await cargarProductos();
  }

  void setClienteVenta(Cliente? c) {
    clienteVenta = c;
    notifyListeners();
  }

  Future<bool> guardarNegocio(Negocio n) async {
    try {
      final db = await _db;
      await DatabaseHelper.instance.ensureSchema(db);
      await db.update(
        'negocio',
        {
          'nombre': n.nombre,
          'nit': n.nit,
          'direccion': n.direccion,
          'es_pro': n.esPro ? 1 : 0,
          'reportes_mes': n.reportesUsadosMes,
          'mes_reportes': n.mesReportes,
          'permitir_stock_negativo': n.permitirStockNegativo ? 1 : 0,
          'es_demo': n.esDemo ? 1 : 0,
          'codigo_nube': n.codigoNube,
        },
        where: 'id = 1',
      );
      negocio = n;
      notifyListeners();
      unawaited(_subirNube());
      return true;
    } catch (e) {
      debugPrint('guardarNegocio: $e');
      return false;
    }
  }

  Future<void> activarPro() async {
    await guardarNegocio(negocio.copyWith(esPro: true));
  }

  Future<void> desactivarPro() async {
    await guardarNegocio(negocio.copyWith(esPro: false, permitirStockNegativo: false));
  }

  Future<Resultado> agregarProducto(Producto producto) async {
    if (!negocio.esPro && productos.length >= limiteSkuGratis) {
      return const Resultado(ok: false, reason: 'limite');
    }
    try {
      final db = await _db;
      await db.insert('productos', producto.toMap());
      if (negocio.esDemo) await guardarNegocio(negocio.copyWith(esDemo: false));
      await cargarProductos();
      return const Resultado(ok: true);
    } catch (e) {
      debugPrint('agregarProducto: $e');
      return const Resultado(ok: false, reason: 'db');
    }
  }

  Future<void> actualizarProducto(Producto producto) async {
    if (producto.id == null) return;
    final db = await _db;
    await db.update('productos', producto.toMap(), where: 'id = ?', whereArgs: [producto.id]);
    await cargarProductos();
  }

  Future<void> eliminarProducto(int id) async {
    final db = await _db;
    await db.update('productos', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
    carrito = carrito.where((c) => c.productoId != id).toList();
    await cargarProductos();
  }

  void setTipoCarrito(String t) {
    tipoCarrito = t;
    motivo = t == 'ENTRADA' ? 'Compra a proveedor' : 'Venta';
    carrito = [];
    if (t != 'SALIDA') clienteVenta = null;
    notifyListeners();
  }

  void setMotivo(String v) {
    motivo = v;
    notifyListeners();
  }

  void setReferencia(String v) {
    referencia = v;
    notifyListeners();
  }

  void setProveedorDoc(String v) {
    proveedorDoc = v;
    notifyListeners();
  }

  Producto? _prod(int id) {
    final found = productos.where((p) => p.id == id);
    return found.isEmpty ? null : found.first;
  }

  int cantidadEnCarrito(int productoId) {
    final found = carrito.where((c) => c.productoId == productoId);
    return found.isEmpty ? 0 : found.first.cantidad;
  }

  Resultado addCarrito(int productoId) {
    final prod = _prod(productoId);
    if (prod == null) return const Resultado(ok: false, reason: 'producto');
    final next = cantidadEnCarrito(productoId) + 1;
    if (tipoCarrito == 'SALIDA' && next > prod.stockActual && !negocio.permitirStockNegativo) {
      return const Resultado(ok: false, reason: 'stock');
    }
    final existing = carrito.where((c) => c.productoId == productoId);
    if (existing.isNotEmpty) {
      carrito = carrito.map((c) => c.productoId == productoId ? c.copyWith(cantidad: next) : c).toList();
    } else {
      carrito = [...carrito, CarritoItem(productoId: productoId, cantidad: 1, costoUnitario: prod.costo)];
    }
    notifyListeners();
    return const Resultado(ok: true);
  }

  void quitarCarrito(int productoId) {
    final n = cantidadEnCarrito(productoId);
    if (n <= 1) {
      carrito = carrito.where((c) => c.productoId != productoId).toList();
    } else {
      carrito = carrito.map((c) => c.productoId == productoId ? c.copyWith(cantidad: n - 1) : c).toList();
    }
    notifyListeners();
  }

  Resultado setCantidad(int productoId, int cantidad) {
    final n = cantidad < 0 ? 0 : cantidad;
    final prod = _prod(productoId);
    if (prod == null) return const Resultado(ok: false, reason: 'producto');
    if (tipoCarrito == 'SALIDA' && n > prod.stockActual && !negocio.permitirStockNegativo) {
      return const Resultado(ok: false, reason: 'stock');
    }
    if (n == 0) {
      carrito = carrito.where((c) => c.productoId != productoId).toList();
      notifyListeners();
      return const Resultado(ok: true);
    }
    final existing = carrito.where((c) => c.productoId == productoId);
    if (existing.isNotEmpty) {
      carrito = carrito.map((c) => c.productoId == productoId ? c.copyWith(cantidad: n) : c).toList();
    } else {
      carrito = [...carrito, CarritoItem(productoId: productoId, cantidad: n, costoUnitario: prod.costo)];
    }
    notifyListeners();
    return const Resultado(ok: true);
  }

  void setCostoItem(int productoId, double costo) {
    carrito = carrito
        .map((c) => c.productoId == productoId ? c.copyWith(costoUnitario: costo < 0 ? 0 : costo) : c)
        .toList();
    notifyListeners();
  }

  Future<Resultado> registrarMovimiento({
    required int productoId,
    required String tipoMovimiento,
    required int cantidad,
    required double costoHistorico,
    String? motivoMov,
    String? referenciaMov,
  }) async {
    tipoCarrito = tipoMovimiento;
    carrito = [CarritoItem(productoId: productoId, cantidad: cantidad, costoUnitario: costoHistorico)];
    if (motivoMov != null) motivo = motivoMov;
    if (referenciaMov != null) referencia = referenciaMov;
    return finalizarCarrito();
  }

  Future<Resultado> movimientoDesdeEscritorio({
    required int productoId,
    required String tipo,
    required int cantidad,
  }) async {
    final backupTipo = tipoCarrito;
    final backupCarrito = List<CarritoItem>.from(carrito);
    final backupMotivo = motivo;
    final backupRef = referencia;
    final backupProv = proveedorDoc;
    final backupCli = clienteVenta;
    tipoCarrito = tipo;
    motivo = tipo == 'ENTRADA' ? 'Compra a proveedor' : 'Venta';
    referencia = 'Computador';
    proveedorDoc = '';
    clienteVenta = null;
    carrito = [
      CarritoItem(productoId: productoId, cantidad: cantidad, costoUnitario: _prod(productoId)?.costo ?? 0),
    ];
    final r = await finalizarCarrito();
    tipoCarrito = backupTipo;
    carrito = backupCarrito;
    motivo = backupMotivo;
    referencia = backupRef;
    proveedorDoc = backupProv;
    clienteVenta = backupCli;
    notifyListeners();
    return r;
  }

  Future<Resultado> finalizarCarrito() async {
    if (carrito.isEmpty) return const Resultado(ok: false, reason: 'vacio');
    for (final item in carrito) {
      final p = _prod(item.productoId);
      if (p == null) return const Resultado(ok: false, reason: 'producto');
      if (item.cantidad <= 0) return const Resultado(ok: false, reason: 'cantidad');
      if (tipoCarrito == 'SALIDA' && item.cantidad > p.stockActual && !negocio.permitirStockNegativo) {
        return Resultado(ok: false, reason: 'stock', codigoRef: p.codigoRef);
      }
    }

    final db = await _db;
    final loteId = 'lote_${DateTime.now().millisecondsSinceEpoch}';
    final fecha = hoyISO();
    var count = 0;
    final cliId = tipoCarrito == 'SALIDA' ? clienteVenta?.id : null;
    final cliNom = tipoCarrito == 'SALIDA' ? (clienteVenta?.nombre ?? '') : '';

    await db.transaction((txn) async {
      for (final item in carrito) {
        final p = _prod(item.productoId)!;
        final stockAntes = p.stockActual;
        final stockDespues = tipoCarrito == 'ENTRADA' ? stockAntes + item.cantidad : stockAntes - item.cantidad;

        var costo = p.costo;
        if (tipoCarrito == 'ENTRADA' && item.costoUnitario > 0) {
          final den = stockAntes + item.cantidad;
          costo = den > 0 ? (stockAntes * p.costo + item.cantidad * item.costoUnitario) / den : item.costoUnitario;
        }

        await txn.update(
          'productos',
          {'stock_actual': stockDespues, 'costo': costo},
          where: 'id = ?',
          whereArgs: [p.id],
        );

        await txn.insert('movimientos', {
          'producto_id': p.id,
          'producto_nombre': p.nombre,
          'codigo_ref': p.codigoRef,
          'tipo_movimiento': tipoCarrito,
          'cantidad': item.cantidad,
          'stock_antes': stockAntes,
          'stock_despues': stockDespues,
          'costo_historico': tipoCarrito == 'ENTRADA' ? item.costoUnitario : p.costo,
          'motivo': motivo,
          'referencia': referencia.trim(),
          'fecha': fecha,
          'lote_id': loteId,
          'proveedor': tipoCarrito == 'ENTRADA' ? proveedorDoc.trim() : null,
          'cliente_id': cliId,
          'cliente_nombre': cliNom,
        });
        count++;
      }
    });

    carrito = [];
    referencia = '';
    await cargarProductos();
    return Resultado(ok: true, count: count);
  }

  Future<Resultado> ajustar({
    required int productoId,
    required int stockNuevo,
    required String motivoAjuste,
    required String referenciaAjuste,
  }) async {
    if (stockNuevo < 0) return const Resultado(ok: false, reason: 'cantidad');
    final p = _prod(productoId);
    if (p == null) return const Resultado(ok: false, reason: 'producto');
    final db = await _db;
    await db.update('productos', {'stock_actual': stockNuevo}, where: 'id = ?', whereArgs: [p.id]);
    await db.insert('movimientos', {
      'producto_id': p.id,
      'producto_nombre': p.nombre,
      'codigo_ref': p.codigoRef,
      'tipo_movimiento': 'AJUSTE',
      'cantidad': (stockNuevo - p.stockActual).abs(),
      'stock_antes': p.stockActual,
      'stock_despues': stockNuevo,
      'costo_historico': p.costo,
      'motivo': motivoAjuste,
      'referencia': referenciaAjuste,
      'fecha': hoyISO(),
    });
    await cargarProductos();
    return const Resultado(ok: true);
  }

  Future<Resultado> aplicarConteo(List<({int productoId, int contado})> items) async {
    final loteId = 'conteo_${DateTime.now().millisecondsSinceEpoch}';
    final fecha = hoyISO();
    final db = await _db;
    var cambios = 0;
    await db.transaction((txn) async {
      for (final item in items) {
        final p = _prod(item.productoId);
        if (p == null) continue;
        final contado = item.contado < 0 ? 0 : item.contado;
        if (contado == p.stockActual) continue;
        await txn.update('productos', {'stock_actual': contado}, where: 'id = ?', whereArgs: [p.id]);
        await txn.insert('movimientos', {
          'producto_id': p.id,
          'producto_nombre': p.nombre,
          'codigo_ref': p.codigoRef,
          'tipo_movimiento': 'AJUSTE',
          'cantidad': (contado - p.stockActual).abs(),
          'stock_antes': p.stockActual,
          'stock_despues': contado,
          'costo_historico': p.costo,
          'motivo': 'Ajuste de conteo',
          'referencia': 'Conteo del estante',
          'fecha': fecha,
          'lote_id': loteId,
        });
        cambios++;
      }
    });
    if (cambios == 0) return const Resultado(ok: false, reason: 'sin-cambios');
    await cargarProductos();
    return Resultado(ok: true, count: cambios);
  }

  Future<Resultado> consumirReporte() async {
    if (negocio.esPro) return const Resultado(ok: true, necesitaAnuncio: false);
    if (negocio.reportesUsadosMes >= limiteReportesGratis) {
      return const Resultado(ok: false, reason: 'limite', necesitaAnuncio: false);
    }
    final n = negocio.copyWith(reportesUsadosMes: negocio.reportesUsadosMes + 1);
    await guardarNegocio(n);
    return const Resultado(ok: true, necesitaAnuncio: true);
  }

  Future<void> restaurarDemo() async {
    final db = await _db;
    await DatabaseHelper.instance.ensureSchema(db);
    await db.delete('movimientos');
    await db.delete('productos');
    await db.update(
      'negocio',
      {
        'nombre': demoNombre,
        'nit': demoNit,
        'direccion': demoDireccion,
        'es_pro': 0,
        'reportes_mes': 0,
        'mes_reportes': mesClave(),
        'permitir_stock_negativo': 0,
        'es_demo': 1,
      },
      where: 'id = 1',
    );
    await seedDemo(db);
    tipoCarrito = 'ENTRADA';
    carrito = [];
    motivo = 'Compra a proveedor';
    referencia = '';
    proveedorDoc = '';
    clienteVenta = null;
    await cargarProductos();
  }

  Future<Resultado> vaciarHistorial() async {
    try {
      final db = await _db;
      await db.delete('movimientos');
      _historialReset = DateTime.now().millisecondsSinceEpoch;
      await cargarProductos();
      return const Resultado(ok: true);
    } catch (e) {
      debugPrint('vaciarHistorial: $e');
      return const Resultado(ok: false, reason: 'db');
    }
  }

  Future<void> vaciarBodega() async {
    final db = await _db;
    await DatabaseHelper.instance.ensureSchema(db);
    await db.delete('movimientos');
    await db.delete('productos');
    await db.update(
      'negocio',
      {
        'nombre': '',
        'nit': '',
        'direccion': '',
        'reportes_mes': 0,
        'mes_reportes': mesClave(),
        'permitir_stock_negativo': 0,
        'es_demo': 0,
      },
      where: 'id = 1',
    );
    tipoCarrito = 'ENTRADA';
    carrito = [];
    motivo = 'Compra a proveedor';
    referencia = '';
    proveedorDoc = '';
    clienteVenta = null;
    await cargarProductos();
  }

  double valorCarrito() {
    return carrito.fold(0, (sum, item) {
      final p = _prod(item.productoId);
      if (p == null) return sum;
      final unit = tipoCarrito == 'ENTRADA' ? (item.costoUnitario != 0 ? item.costoUnitario : p.costo) : p.costo;
      return sum + unit * item.cantidad;
    });
  }
}