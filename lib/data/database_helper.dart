import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/types.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rapistock.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: (db, oldV, newV) => ensureSchema(db),
      onOpen: ensureSchema,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo_ref TEXT NOT NULL,
        nombre TEXT NOT NULL,
        categoria TEXT NOT NULL DEFAULT 'Mercado',
        unidad TEXT NOT NULL DEFAULT 'und',
        stock_actual INTEGER NOT NULL,
        stock_minimo INTEGER NOT NULL DEFAULT 10,
        costo REAL NOT NULL,
        precio_venta REAL NOT NULL,
        proveedor TEXT NOT NULL DEFAULT '',
        ubicacion TEXT NOT NULL DEFAULT '',
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        producto_nombre TEXT NOT NULL DEFAULT '',
        codigo_ref TEXT NOT NULL DEFAULT '',
        tipo_movimiento TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        stock_antes INTEGER NOT NULL DEFAULT 0,
        stock_despues INTEGER NOT NULL DEFAULT 0,
        costo_historico REAL NOT NULL DEFAULT 0,
        motivo TEXT NOT NULL DEFAULT '',
        referencia TEXT NOT NULL DEFAULT '',
        fecha TEXT NOT NULL,
        lote_id TEXT,
        proveedor TEXT,
        cliente_id INTEGER,
        cliente_nombre TEXT NOT NULL DEFAULT ''
      )
    ''');

    await _crearNegocio(db);
    await _crearCategorias(db);
    await _crearClientes(db);
  }

  Future<void> ensureSchema(Database db) async {
    Future<void> addCol(String table, String col, String spec) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $col $spec');
      } catch (_) {}
    }

    await addCol('productos', 'categoria', "TEXT NOT NULL DEFAULT 'Mercado'");
    await addCol('productos', 'unidad', "TEXT NOT NULL DEFAULT 'und'");
    await addCol('productos', 'stock_minimo', 'INTEGER NOT NULL DEFAULT 10');
    await addCol('productos', 'proveedor', "TEXT NOT NULL DEFAULT ''");
    await addCol('productos', 'ubicacion', "TEXT NOT NULL DEFAULT ''");
    await addCol('productos', 'activo', 'INTEGER NOT NULL DEFAULT 1');

    await addCol('movimientos', 'producto_nombre', "TEXT NOT NULL DEFAULT ''");
    await addCol('movimientos', 'codigo_ref', "TEXT NOT NULL DEFAULT ''");
    await addCol('movimientos', 'stock_antes', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('movimientos', 'stock_despues', 'INTEGER NOT NULL DEFAULT 0');
    await addCol('movimientos', 'motivo', "TEXT NOT NULL DEFAULT ''");
    await addCol('movimientos', 'referencia', "TEXT NOT NULL DEFAULT ''");
    await addCol('movimientos', 'lote_id', 'TEXT');
    await addCol('movimientos', 'proveedor', 'TEXT');
    await addCol('movimientos', 'cliente_id', 'INTEGER');
    await addCol('movimientos', 'cliente_nombre', "TEXT NOT NULL DEFAULT ''");

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='negocio'",
    );
    if (tables.isEmpty) {
      await _crearNegocio(db);
    } else {
      await addCol('negocio', 'es_demo', 'INTEGER NOT NULL DEFAULT 0');
      await addCol('negocio', 'codigo_nube', "TEXT NOT NULL DEFAULT ''");
      final n = await db.query('negocio', where: 'id = 1');
      if (n.isEmpty) {
        await db.insert('negocio', _negocioVacio());
      }
    }
    await _crearCategorias(db);
    await _crearClientes(db);
  }

  Map<String, Object?> _negocioVacio() => {
    'id': 1,
    'nombre': '',
    'nit': '',
    'direccion': '',
    'es_pro': 0,
    'reportes_mes': 0,
    'mes_reportes': mesClave(),
    'permitir_stock_negativo': 0,
    'es_demo': 0,
    'codigo_nube': '',
  };

  Future<void> _crearNegocio(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS negocio (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        nit TEXT NOT NULL,
        direccion TEXT NOT NULL,
        es_pro INTEGER NOT NULL DEFAULT 0,
        reportes_mes INTEGER NOT NULL DEFAULT 0,
        mes_reportes TEXT NOT NULL DEFAULT '',
        permitir_stock_negativo INTEGER NOT NULL DEFAULT 0,
        es_demo INTEGER NOT NULL DEFAULT 0,
        codigo_nube TEXT NOT NULL DEFAULT ''
      )
    ''');
    final n = await db.query('negocio', where: 'id = 1');
    if (n.isEmpty) {
      await db.insert('negocio', _negocioVacio());
    }
  }

  Future<void> _crearCategorias(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        nombre TEXT PRIMARY KEY,
        prefijo TEXT NOT NULL UNIQUE
      )
    ''');
  }

  Future<void> _crearClientes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        telefono TEXT NOT NULL DEFAULT '',
        nit TEXT NOT NULL DEFAULT '',
        direccion TEXT NOT NULL DEFAULT '',
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}