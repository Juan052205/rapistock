import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/types.dart';
import '../widgets/ad_gate.dart';
import 'format.dart';
import 'store.dart';

class RangoExport {
  final DateTime? desde;
  final DateTime? hasta;
  final String etiqueta;
  const RangoExport({this.desde, this.hasta, required this.etiqueta});

  static const todo = RangoExport(etiqueta: 'Todo');

  static RangoExport mesActual() {
    final n = DateTime.now();
    return RangoExport(
      desde: DateTime(n.year, n.month, 1),
      hasta: DateTime(n.year, n.month + 1, 0, 23, 59, 59),
      etiqueta: 'Este mes',
    );
  }

  static RangoExport semanaActual() {
    final n = DateTime.now();
    final lunes = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    return RangoExport(
      desde: lunes,
      hasta: lunes.add(const Duration(days: 6, hours: 23, minutes: 59)),
      etiqueta: 'Esta semana',
    );
  }

  bool incluye(String fechaIso) {
    if (desde == null && hasta == null) return true;
    final d = DateTime.tryParse(fechaIso);
    if (d == null) return false;
    if (desde != null && d.isBefore(desde!)) return false;
    if (hasta != null && d.isAfter(hasta!)) return false;
    return true;
  }

  String get archivoSufijo {
    if (desde == null) return 'todo-${fechaArchivo(DateTime.now())}';
    if (etiqueta == 'Este mes') return mesArchivo(desde!);
    final h = hasta ?? desde!;
    return '${fechaArchivo(desde!)}-a-${fechaArchivo(h)}';
  }
}

String slug(String s) {
  const map = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
    'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u',
    'ñ': 'n', 'Ñ': 'n',
  };
  var t = s.toLowerCase();
  map.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  t = t.replaceAll(RegExp(r'^-|-$'), '');
  if (t.length > 40) t = t.substring(0, 40);
  return t.isEmpty ? 'rapistock' : t;
}

String clienteExcel(Movimiento m) {
  if (m.tipoMovimiento != 'SALIDA') return '';
  final n = m.clienteNombre.trim();
  return n.isEmpty ? 'Mostrador (cliente de paso)' : n;
}

class ExportarService {
  static List<List<Object>> _encabezado(Negocio n, String titulo) {
    final nombre = n.nombre.trim().isEmpty ? 'Mi negocio' : n.nombre.trim();
    return [
      [titulo],
      ['Negocio', nombre],
      if (n.nit.trim().isNotEmpty) ['NIT', n.nit.trim()],
      if (n.direccion.trim().isNotEmpty) ['Dirección', n.direccion.trim()],
      ['Fecha del archivo', fechaCorta(DateTime.now().toIso8601String())],
      [''],
    ];
  }

  static List<List<Object>> filasInventario(List<Producto> productos, Negocio negocio) => [
    ..._encabezado(negocio, 'Lista de productos'),
    [
      'Código',
      'Nombre',
      'Categoría',
      'Unidad',
      'Cantidad',
      'Mínimo',
      'Costo',
      'Precio de venta',
      'Valor',
      'Proveedor',
      'Ubicación',
    ],
    ...productos.map(
          (p) => [
        p.codigoRef,
        p.nombre,
        p.categoria,
        p.unidad,
        p.stockActual,
        p.stockMinimo,
        p.costo.round(),
        p.precioVenta.round(),
        (p.stockActual * p.costo).round(),
        p.proveedor,
        p.ubicacion,
      ],
    ),
  ];

  static List<List<Object>> filasHistorial(
      List<Movimiento> movimientos,
      Negocio negocio, [
        RangoExport rango = RangoExport.todo,
      ]) =>
      [
        ..._encabezado(negocio, 'Historial de movimientos · ${rango.etiqueta}'),
        [
          'Fecha',
          'Qué pasó',
          'Código',
          'Producto',
          'Cantidad',
          'Antes',
          'Después',
          'Motivo',
          'Factura o nota',
          'Cliente',
        ],
        ...movimientos.where((m) => rango.incluye(m.fecha)).map(
              (m) => [
            fechaCorta(m.fecha),
            m.tipoMovimiento == 'ENTRADA'
                ? 'Entró'
                : m.tipoMovimiento == 'SALIDA'
                ? 'Salió'
                : 'Corrección',
            m.codigoRef,
            m.productoNombre,
            m.cantidad,
            m.stockAntes,
            m.stockDespues,
            m.motivo,
            m.referencia,
            clienteExcel(m),
          ],
        ),
      ];

  static Border get _borde => Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#C8C8C8'),
  );

  static CellStyle get _cel => CellStyle(
    leftBorder: _borde,
    rightBorder: _borde,
    topBorder: _borde,
    bottomBorder: _borde,
    verticalAlign: VerticalAlign.Center,
  );

  static CellStyle get _head => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#1B4D3E'),
    fontColorHex: ExcelColor.white,
    leftBorder: _borde,
    rightBorder: _borde,
    topBorder: _borde,
    bottomBorder: _borde,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  static CellStyle get _titulo => CellStyle(
    bold: true,
    fontSize: 14,
    fontColorHex: ExcelColor.fromHexString('#1B4D3E'),
  );

  static CellStyle get _etiqueta => CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#E8F0EC'),
    leftBorder: _borde,
    rightBorder: _borde,
    topBorder: _borde,
    bottomBorder: _borde,
  );

  static List<int> _xlsx(List<List<Object>> filas, String hoja) {
    final book = Excel.createExcel();
    final defaultSheet = book.tables.keys.first;
    if (defaultSheet != hoja) {
      book.rename(defaultSheet, hoja);
    }
    final sheet = book[hoja];

    var headerRow = -1;
    for (var i = 0; i < filas.length; i++) {
      if (filas[i].length >= 5) {
        headerRow = i;
        break;
      }
    }

    var maxC = 1;
    for (final row in filas) {
      if (row.length > maxC) maxC = row.length;
    }

    for (var r = 0; r < filas.length; r++) {
      for (var c = 0; c < filas[r].length; c++) {
        final raw = filas[r][c];
        final CellValue value;
        if (raw is int) {
          value = IntCellValue(raw);
        } else if (raw is double) {
          value = IntCellValue(raw.round());
        } else if (raw is num) {
          value = IntCellValue(raw.round());
        } else {
          value = TextCellValue(raw.toString());
        }
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.value = value;
        if (r == headerRow) {
          cell.cellStyle = _head;
        } else if (headerRow >= 0 && r > headerRow) {
          cell.cellStyle = _cel;
        } else if (r == 0) {
          cell.cellStyle = _titulo;
        } else if (filas[r].length == 2 && c == 0 && (filas[r][0].toString().trim().isNotEmpty)) {
          cell.cellStyle = _etiqueta;
        }
      }
    }

    const anchos = [22.0, 16.0, 14.0, 28.0, 12.0, 12.0, 14.0, 22.0, 20.0, 26.0, 18.0];
    for (var c = 0; c < maxC; c++) {
      sheet.setColumnWidth(c, c < anchos.length ? anchos[c] : 16.0);
    }
    if (headerRow >= 0) {
      sheet.setRowHeight(headerRow, 22);
    }

    return book.encode() ?? [];
  }

  static Future<bool> exportar({
    required BuildContext context,
    required Store store,
    required String nombreArchivo,
    required List<List<Object>> filas,
    bool soloPro = false,
    bool contarComoReporte = true,
  }) async {
    if (soloPro && !store.negocio.esPro) return false;

    if (contarComoReporte && !store.negocio.esPro) {
      final seguir = await anuncioSiGratis(context, esPro: false);
      if (seguir != true) return false;
    }

    if (contarComoReporte) {
      final r = await store.consumirReporte();
      if (!r.ok) return false;
    }

    final dir = await getTemporaryDirectory();
    final nombre = nombreArchivo.endsWith('.xlsx') ? nombreArchivo : '$nombreArchivo.xlsx';
    final file = File('${dir.path}/$nombre');
    await file.writeAsBytes(_xlsx(filas, 'Rapistock'));

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: nombre)],
      subject: nombre,
    );
    return true;
  }
}