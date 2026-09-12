import 'dart:convert'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; 
import '../screens/login_screen.dart'; 
import 'local_db_service.dart'; 

class DatabaseService {
  final _supabase = Supabase.instance.client;

  Future<String> guardarPedido({
    required int mesa,
    required int total,
    required List<Map<String, dynamic>> productos,
    String estado = 'preparando', 
    int? mozoId, // Agregamos el parámetro opcional por si lo pasamos directo desde la UI
  }) async {
    try {
      final conectividad = await Connectivity().checkConnectivity();
      bool sinInternet = false;
      
      if (conectividad is List) {
        sinInternet = (conectividad as List).contains(ConnectivityResult.none) || (conectividad as List).isEmpty;
      } else {
        sinInternet = conectividad == ConnectivityResult.none;
      }

      
      final idMozoFinal = mozoId ?? SesionGlobal.idUsuarioActual;

      if (sinInternet) {
        print('Sin internet. Guardando pedido de mesa $mesa en memoria local...');
        await LocalDbService().guardarPedidoOffline(
          mesa, 
          total, 
          idMozoFinal, 
          productos
        );
        return 'offline'; 
      }

      await _enviarASupabase(mesa, total, productos, estado, idMozoFinal);
      await sincronizarPedidosOffline();

      return 'online';
      
    } catch (e) {
      print('Error en DatabaseService: $e');
      rethrow;
    }
  }

  Future<void> _enviarASupabase(int mesa, int total, List<dynamic> productos, String estado, int? mozoId) async {
    final nuevoPedido = await _supabase.from('pedidos').insert({
      'numero_mesa': mesa,
      'estado': estado,
      'total': total,
      'metodo_pago': 'pendiente',
      'mozo_id': mozoId, 
    }).select().single();

    final pedidoId = nuevoPedido['id'];

    final itemsParaGuardar = productos.map((prod) {
      return {
        'pedido_id': pedidoId,
        'producto_id': prod['id'],
        'cantidad': 1,
        'notas': prod['notas'] ?? '',
      };
    }).toList();

    await _supabase.from('pedido_items').insert(itemsParaGuardar);
    
    // Acá es donde llamamos a la magia matemática de descuento
    await descontarStockPorPedido(productos.cast<Map<String, dynamic>>());
  }

  Future<void> sincronizarPedidosOffline() async {
    final pendientes = await LocalDbService().obtenerPedidosPendientes();
    
    if (pendientes.isEmpty) return; 
    
    print('⏳ Sincronizando ${pendientes.length} pedidos offline retenidos hacia Supabase...');
    
    for (var p in pendientes) {
      try {
        final int idLocal = p['id'];
        final int mesa = p['mesa'];
        final int total = p['total'];
        final int? mozoId = p['mozo_id'];
        
        final List<dynamic> productosDecodificados = jsonDecode(p['productos_json']);
        
        await _enviarASupabase(mesa, total, productosDecodificados, 'preparando', mozoId);
        await LocalDbService().borrarPedidoSincronizado(idLocal);
        print('✅ Pedido local $idLocal enviado y limpiado con éxito');
        
      } catch (e) {
        print('❌ Error al sincronizar pedido atrasado: $e');
      }
    }
  }

  // ✨ MODIFICACIÓN: Nuevo motor con cálculos matemáticos de conversión
  Future<void> descontarStockPorPedido(List<Map<String, dynamic>> productos) async {
    for (var producto in productos) {
      final recetas = await _supabase
          .from('recetas')
          .select('insumo_id, cantidad_necesaria, unidad_medida_receta')
          .eq('producto_id', producto['id']);

      for (var receta in recetas) {
        final insumoId = receta['insumo_id'];
        final cantidadUsada = (receta['cantidad_necesaria'] as num).toDouble();
        final unidadReceta = receta['unidad_medida_receta']?.toString() ?? '';

        // 1. Buscamos la unidad base del insumo directamente en su tabla
        final insumoData = await _supabase
            .from('insumos')
            .select('unidad_medida')
            .eq('id', insumoId)
            .maybeSingle();

        final unidadBase = insumoData?['unidad_medida']?.toString() ?? '';

        // 2. Ejecutamos el motor de conversión
        double cantidadADescontar = _calcularConversion(cantidadUsada, unidadReceta, unidadBase);

        // 3. Enviamos el número YA CONVERTIDO a Supabase
        await _supabase.rpc('descontar_insumo', params: {
          'p_insumo_id': insumoId,
          'p_cantidad': cantidadADescontar,
        });
      }
    }
  }

  // 🧠 CEREBRO MATEMÁTICO DE CONVERSIÓN DE MEDIDAS
  double _calcularConversion(double cantidad, String unidadReceta, String unidadBase) {
    String siglaReceta = _extraerSigla(unidadReceta.toLowerCase());
    String siglaBase = _extraerSigla(unidadBase.toLowerCase());

    // Si son exactamente la misma medida (Ej: kg con kg), restamos directo
    if (siglaReceta == siglaBase) {
      return cantidad; 
    }

    // De Gramos a Kilos (Ej: Receta pide 200g, el stock está en Kg)
    if (siglaReceta == 'g' && siglaBase == 'kg') return cantidad / 1000;
    
    // De Kilos a Gramos (Ej: Receta pide 0.5kg, el stock está en Gramos)
    if (siglaReceta == 'kg' && siglaBase == 'g') return cantidad * 1000;
    
    // De Mililitros a Litros (Ej: Receta pide 50ml, el stock está en Litros)
    if (siglaReceta == 'ml' && siglaBase == 'l') return cantidad / 1000;
    
    // De Litros a Mililitros
    if (siglaReceta == 'l' && siglaBase == 'ml') return cantidad * 1000;

    // Si es una mezcla incompatible o no mapeada (Ej: Unidades con Kilos), pasa crudo por defecto.
    return cantidad; 
  }

  // Función auxiliar para extraer solo la parte importante de la unidad
  String _extraerSigla(String texto) {
    if (texto.contains('(kg)')) return 'kg';
    if (texto.contains('(g)')) return 'g';
    if (texto.contains('(l)')) return 'l';
    if (texto.contains('(ml)')) return 'ml';
    if (texto.contains('(u)')) return 'u';
    return '';
  }
}