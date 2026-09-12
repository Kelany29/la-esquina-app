import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert'; 
import 'package:flutter/foundation.dart' show kIsWeb; 

class LocalDbService {
  static final LocalDbService _instancia = LocalDbService._interno();
  factory LocalDbService() => _instancia;
  LocalDbService._interno();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // Si por alguna razón llega a ejecutarse en Web, detenemos la inicialización
    if (kIsWeb) throw Exception("SQLite no está soportado en la Web");

    final directorio = await getDatabasesPath();
    final path = join(directorio, 'la_esquina_offline.db');

    return await openDatabase(
      path,
      version: 2, 
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE usuarios_offline(
              id INTEGER PRIMARY KEY,
              nombre TEXT,
              rol TEXT,
              pin TEXT,
              activo INTEGER
            )
          ''');
        }
      },
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE pedidos_offline(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mesa INTEGER,
            total INTEGER,
            mozo_id INTEGER,
            productos_json TEXT,
            fecha TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE usuarios_offline(
            id INTEGER PRIMARY KEY,
            nombre TEXT,
            rol TEXT,
            pin TEXT,
            activo INTEGER
          )
        ''');
      },
    );
  }

  // --- MÉTODOS DE PEDIDOS ---
  Future<int> guardarPedidoOffline(int mesa, int total, int? mozoId, List<Map<String, dynamic>> productos) async {
    if (kIsWeb) return 0; // ✨ ESCUDO WEB: No guarda offline si está en la compu
    
    final base = await db;
    final productosString = jsonEncode(productos);
    return await base.insert('pedidos_offline', {
      'mesa': mesa,
      'total': total,
      'mozo_id': mozoId,
      'productos_json': productosString,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPedidosPendientes() async {
    if (kIsWeb) return []; // ✨ ESCUDO WEB: Devuelve lista vacía, no busca en el disco duro
    
    final base = await db;
    return await base.query('pedidos_offline', orderBy: 'id ASC');
  }

  Future<void> borrarPedidoSincronizado(int id) async {
    if (kIsWeb) return; // ✨ ESCUDO WEB
    
    final base = await db;
    await base.delete('pedidos_offline', where: 'id = ?', whereArgs: [id]);
  }

  // --- MÉTODOS DE USUARIOS ---
  Future<void> guardarUsuariosOffline(List<dynamic> usuarios) async {
    if (kIsWeb) return; // ✨ ESCUDO WEB
    
    final base = await db;
    await base.delete('usuarios_offline'); 
    for (var u in usuarios) {
      await base.insert('usuarios_offline', {
        'id': u['id'],
        'nombre': u['nombre'],
        'rol': u['rol'],
        'pin': u['pin'].toString(),
        'activo': u['activo'] == true ? 1 : 0, 
      });
    }
  }

  Future<Map<String, dynamic>?> verificarPinOffline(String pin) async {
    if (kIsWeb) return null; // ✨ ESCUDO WEB: Al devolver null, obliga a la Web a verificar con Supabase en la nube
    
    final base = await db;
    final resultado = await base.query('usuarios_offline', where: 'pin = ?', whereArgs: [pin]);
    
    if (resultado.isNotEmpty) {
      final data = resultado.first;
      return {
        'id': data['id'],
        'nombre': data['nombre'],
        'rol': data['rol'],
        'activo': data['activo'] == 1,
      };
    }
    return null;
  }
}