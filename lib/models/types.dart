class Producto {
  final int? id;
  final String codigoRef;
  final String nombre;
  final String categoria;
  final String unidad;
  final int stockActual;
  final int stockMinimo;
  final double costo;
  final double precioVenta;
  final String proveedor;
  final String ubicacion;
  final int activo;

  const Producto({
    this.id,
    required this.codigoRef,
    required this.nombre,
    this.categoria = 'Mercado',
    this.unidad = 'und',
    required this.stockActual,
    this.stockMinimo = 10,
    required this.costo,
    required this.precioVenta,
    this.proveedor = '',
    this.ubicacion = '',
    this.activo = 1,
  });

  Producto copyWith({
    int? id,
    String? codigoRef,
    String? nombre,
    String? categoria,
    String? unidad,
    int? stockActual,
    int? stockMinimo,
    double? costo,
    double? precioVenta,
    String? proveedor,
    String? ubicacion,
    int? activo,
  }) {
    return Producto(
      id: id ?? this.id,
      codigoRef: codigoRef ?? this.codigoRef,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      unidad: unidad ?? this.unidad,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      costo: costo ?? this.costo,
      precioVenta: precioVenta ?? this.precioVenta,
      proveedor: proveedor ?? this.proveedor,
      ubicacion: ubicacion ?? this.ubicacion,
      activo: activo ?? this.activo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'codigo_ref': codigoRef,
      'nombre': nombre,
      'categoria': categoriaAmigable(categoria),
      'unidad': unidad,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'costo': costo,
      'precio_venta': precioVenta,
      'proveedor': proveedor,
      'ubicacion': ubicacion,
      'activo': activo,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as int?,
      codigoRef: (map['codigo_ref'] ?? map['codigoRef'] ?? '') as String,
      nombre: (map['nombre'] ?? '') as String,
      categoria: categoriaAmigable((map['categoria'] ?? 'Mercado') as String),
      unidad: (map['unidad'] ?? 'und') as String,
      stockActual: (map['stock_actual'] as num?)?.toInt() ?? 0,
      stockMinimo: (map['stock_minimo'] as num?)?.toInt() ?? 10,
      costo: (map['costo'] as num?)?.toDouble() ?? 0,
      precioVenta: (map['precio_venta'] as num?)?.toDouble() ?? 0,
      proveedor: (map['proveedor'] ?? '') as String,
      ubicacion: (map['ubicacion'] ?? '') as String,
      activo: (map['activo'] as num?)?.toInt() ?? 1,
    );
  }
}

class CarritoItem {
  final int productoId;
  final int cantidad;
  final double costoUnitario;

  const CarritoItem({
    required this.productoId,
    required this.cantidad,
    required this.costoUnitario,
  });

  CarritoItem copyWith({int? cantidad, double? costoUnitario}) => CarritoItem(
    productoId: productoId,
    cantidad: cantidad ?? this.cantidad,
    costoUnitario: costoUnitario ?? this.costoUnitario,
  );
}

class Movimiento {
  final int? id;
  final int productoId;
  final String productoNombre;
  final String codigoRef;
  final String tipoMovimiento;
  final int cantidad;
  final int stockAntes;
  final int stockDespues;
  final double costoHistorico;
  final String motivo;
  final String referencia;
  final String fecha;
  final String? loteId;
  final String? proveedor;
  final int? clienteId;
  final String clienteNombre;

  const Movimiento({
    this.id,
    required this.productoId,
    required this.productoNombre,
    required this.codigoRef,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.stockAntes,
    required this.stockDespues,
    required this.costoHistorico,
    this.motivo = '',
    this.referencia = '',
    required this.fecha,
    this.loteId,
    this.proveedor,
    this.clienteId,
    this.clienteNombre = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'producto_id': productoId,
    'producto_nombre': productoNombre,
    'codigo_ref': codigoRef,
    'tipo_movimiento': tipoMovimiento,
    'cantidad': cantidad,
    'stock_antes': stockAntes,
    'stock_despues': stockDespues,
    'costo_historico': costoHistorico,
    'motivo': motivo,
    'referencia': referencia,
    'fecha': fecha,
    'lote_id': loteId,
    'proveedor': proveedor,
    'cliente_id': clienteId,
    'cliente_nombre': clienteNombre,
  };

  factory Movimiento.fromMap(Map<String, dynamic> map) => Movimiento(
    id: map['id'] as int?,
    productoId: (map['producto_id'] as num?)?.toInt() ?? 0,
    productoNombre: (map['producto_nombre'] ?? '') as String,
    codigoRef: (map['codigo_ref'] ?? '') as String,
    tipoMovimiento: (map['tipo_movimiento'] ?? 'AJUSTE') as String,
    cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
    stockAntes: (map['stock_antes'] as num?)?.toInt() ?? 0,
    stockDespues: (map['stock_despues'] as num?)?.toInt() ?? 0,
    costoHistorico: (map['costo_historico'] as num?)?.toDouble() ?? 0,
    motivo: (map['motivo'] ?? '') as String,
    referencia: (map['referencia'] ?? '') as String,
    fecha: (map['fecha'] ?? '') as String,
    loteId: map['lote_id'] as String?,
    proveedor: map['proveedor'] as String?,
    clienteId: (map['cliente_id'] as num?)?.toInt(),
    clienteNombre: (map['cliente_nombre'] ?? '') as String,
  );
}

class Negocio {
  final String nombre;
  final String nit;
  final String direccion;
  final bool esPro;
  final int reportesUsadosMes;
  final String mesReportes;
  final bool permitirStockNegativo;
  final bool esDemo;
  final String codigoNube;

  const Negocio({
    required this.nombre,
    required this.nit,
    required this.direccion,
    required this.esPro,
    required this.reportesUsadosMes,
    required this.mesReportes,
    required this.permitirStockNegativo,
    this.esDemo = false,
    this.codigoNube = '',
  });

  Negocio copyWith({
    String? nombre,
    String? nit,
    String? direccion,
    bool? esPro,
    int? reportesUsadosMes,
    String? mesReportes,
    bool? permitirStockNegativo,
    bool? esDemo,
    String? codigoNube,
  }) =>
      Negocio(
        nombre: nombre ?? this.nombre,
        nit: nit ?? this.nit,
        direccion: direccion ?? this.direccion,
        esPro: esPro ?? this.esPro,
        reportesUsadosMes: reportesUsadosMes ?? this.reportesUsadosMes,
        mesReportes: mesReportes ?? this.mesReportes,
        permitirStockNegativo: permitirStockNegativo ?? this.permitirStockNegativo,
        esDemo: esDemo ?? this.esDemo,
        codigoNube: codigoNube ?? this.codigoNube,
      );
}

class Resultado {
  final bool ok;
  final String? reason;
  final String? codigoRef;
  final int? count;
  final bool necesitaAnuncio;

  const Resultado({
    required this.ok,
    this.reason,
    this.codigoRef,
    this.count,
    this.necesitaAnuncio = false,
  });
}

const int limiteSkuGratis = 12;
const int limiteReportesGratis = 2;
const int umbralHistorial = 100;
const int limiteClientesGratis = 20;
const int maxComputadores = 2;

const List<String> categorias = [
  'Mercado',
  'Lácteos',
  'Bebidas',
  'Aseo',
  'Mecato',
  'Ferretería',
  'Otros',
];

const List<String> unidades = ['und', 'kg', 'lt', 'bulto', 'caja', 'paq'];

const List<String> motivosEntrada = [
  'Compra a proveedor',
  'Devolución de cliente',
  'Traslado recibido',
  'Ajuste de conteo',
];

const List<String> motivosSalida = [
  'Venta',
  'Merma / vencimiento',
  'Uso interno',
  'Traslado enviado',
  'Devolución a proveedor',
];

const Map<String, String> prefijoCategoria = {
  'Mercado': 'ME',
  'Lácteos': 'LA',
  'Bebidas': 'BE',
  'Aseo': 'AS',
  'Mecato': 'MC',
  'Ferretería': 'FE',
  'Otros': 'OT',
};

String categoriaAmigable(String raw) {
  if (raw == 'Abarrotes' || raw.isEmpty) return 'Mercado';
  if (raw == 'Snacks') return 'Mecato';
  return raw;
}

String mesClave([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.year}-${x.month.toString().padLeft(2, '0')}';
}

const String kAgregarCategoria = '__agregar_categoria__';

String letrasCategoria(String nombre) {
  const map = {
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ñ': 'N',
    'Ä': 'A', 'Ü': 'U',
  };
  var s = nombre.trim().toUpperCase();
  map.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll(RegExp(r'[^A-Z]'), '');
}

String generarPrefijo(String nombre, Iterable<String> usados) {
  final tomados = usados.map((e) => e.toUpperCase()).toSet();
  final letras = letrasCategoria(nombre);

  if (letras.length >= 2) {
    final primero = letras.substring(0, 2);
    if (!tomados.contains(primero)) return primero;
    for (var i = 1; i < letras.length; i++) {
      final p = '${letras[0]}${letras[i]}';
      if (!tomados.contains(p)) return p;
    }
  } else if (letras.length == 1) {
    const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var i = 0; i < abc.length; i++) {
      final p = '${letras[0]}${abc[i]}';
      if (!tomados.contains(p)) return p;
    }
  }

  final abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')..shuffle();
  for (final a in abc) {
    for (final b in abc) {
      final p = '$a$b';
      if (!tomados.contains(p)) return p;
    }
  }
  return 'ZZ';
}

String siguienteCodigoDe(List<Producto> productos, String pref) {
  final nums = productos
      .where((p) => p.codigoRef.toUpperCase().startsWith('$pref-'))
      .map((p) => int.tryParse(p.codigoRef.split('-').last) ?? 0)
      .toList();
  final next = (nums.isEmpty ? 0 : nums.reduce((a, b) => a > b ? a : b)) + 1;
  return '$pref-${next.toString().padLeft(3, '0')}';
}

String siguienteCodigo(List<Producto> productos, String categoria, [Map<String, String>? extra]) {
  final mapa = {...prefijoCategoria, ...?extra};
  final pref = mapa[categoria] ?? generarPrefijo(categoria, mapa.values);
  return siguienteCodigoDe(productos, pref);
}

class Cliente {
  final int? id;
  final String nombre;
  final String telefono;
  final String nit;
  final String direccion;
  final int activo;

  const Cliente({
    this.id,
    required this.nombre,
    this.telefono = '',
    this.nit = '',
    this.direccion = '',
    this.activo = 1,
  });

  Cliente copyWith({
    int? id,
    String? nombre,
    String? telefono,
    String? nit,
    String? direccion,
    int? activo,
  }) =>
      Cliente(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        telefono: telefono ?? this.telefono,
        nit: nit ?? this.nit,
        direccion: direccion ?? this.direccion,
        activo: activo ?? this.activo,
      );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'nit': nit,
    'direccion': direccion,
    'activo': activo,
  };

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
    id: map['id'] as int?,
    nombre: (map['nombre'] ?? '') as String,
    telefono: (map['telefono'] ?? '') as String,
    nit: (map['nit'] ?? '') as String,
    direccion: (map['direccion'] ?? '') as String,
    activo: (map['activo'] as num?)?.toInt() ?? 1,
  );
}

class DispositivoNube {
  final String id;
  final String nombre;
  final int lastSeen;

  const DispositivoNube({required this.id, required this.nombre, required this.lastSeen});
}