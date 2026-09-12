import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart'; 
import 'categorias_screen.dart'; 
import 'productos_screen.dart'; 

class PantallaDetalleMesa extends StatefulWidget {
  final int numeroMesa;
  const PantallaDetalleMesa({super.key, required this.numeroMesa});

  @override
  State<PantallaDetalleMesa> createState() => _PantallaDetalleMesaState();
}

class _PantallaDetalleMesaState extends State<PantallaDetalleMesa> {
  late final Stream<List<Map<String, dynamic>>> _streamMesa;

  @override
  void initState() {
    super.initState();
    _streamMesa = Supabase.instance.client
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('numero_mesa', widget.numeroMesa);
  }

  // ✨ NUEVA FUNCIÓN: Elimina un ítem individual y actualiza el total de la mesa
  Future<void> _eliminarItemIndividual(int pedidoItemId, int pedidoId, int precioItem, int totalActual) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Borrar Ítem', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que querés cancelar este plato/bebida? Desaparecerá de la cocina y se restará del total.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Cerramos el diálogo primero
              
              // 1. Borramos el ítem específico
              await Supabase.instance.client
                  .from('pedido_items')
                  .delete()
                  .eq('id', pedidoItemId);

              // 2. Calculamos el nuevo total
              int nuevoTotal = totalActual - precioItem;
              if (nuevoTotal < 0) nuevoTotal = 0; // Por las dudas evitamos totales negativos

              // 3. Actualizamos el total en el pedido padre
              await Supabase.instance.client
                  .from('pedidos')
                  .update({'total': nuevoTotal})
                  .eq('id', pedidoId);
                  
              // Refrescamos la pantalla
              if (mounted) setState(() {});
            }, 
            child: const Text('SÍ, BORRAR ÍTEM')
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ✨ MAGIA APLICADA AQUÍ: Si es > 100 dice BANQUETA, sino dice MESA
        title: Text(
          widget.numeroMesa > 100 
            ? 'CUENTA - BANQUETA ${widget.numeroMesa - 100}B' 
            : 'CUENTA - MESA ${widget.numeroMesa}', 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            tooltip: 'Limpiar Cuenta',
            onPressed: () => _confirmarLimpiezaCuenta(),
          )
        ],
      ),
      backgroundColor: Colors.grey.shade200,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _streamMesa,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final todosLosPedidos = snapshot.data ?? [];
          final pedidosActivos = todosLosPedidos.where((p) {
             final est = p['estado'].toString().toLowerCase();
             return est != 'cobrado' && est != 'archivado';
          }).toList();
          
          int granTotal = 0;
          bool hayComidaLista = false;

          for (var pedido in pedidosActivos) {
            granTotal += (pedido['total'] as num).toInt();
            if (pedido['estado'] == 'listo') hayComidaLista = true;
          }

          return SafeArea(
            child: Column(
              children: [
                if (hayComidaLista)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    color: Colors.amber,
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_active, color: Colors.black87),
                            SizedBox(width: 10),
                            Text('¡HAY COMIDA LISTA PARA RETIRAR!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.amber),
                          onPressed: () => _marcarComoServido(),
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar Entrega en Mesa'),
                        )
                      ],
                    ),
                  ),

                Expanded(
                  child: FutureBuilder(
                    future: Supabase.instance.client.from('pedidos').select('''
                      id, total, estado,
                      pedido_items (
                        id, notas,
                        productos (nombre, precio)
                      )
                    ''').eq('numero_mesa', widget.numeroMesa).neq('estado', 'cobrado').neq('estado', 'archivado'),
                    builder: (context, itemSnapshot) {
                      if (!itemSnapshot.hasData) return const SizedBox.shrink();
                      
                      List<dynamic> renglonesTicket = [];
                      final pedidosConItems = itemSnapshot.data as List<dynamic>;
                      
                      for (var p in pedidosConItems) {
                        final items = p['pedido_items'] as List<dynamic>? ?? [];
                        final pedidoId = p['id'];
                        final totalPedidoActual = (p['total'] as num).toInt();

                        for (var it in items) {
                          renglonesTicket.add({
                            'item_id': it['id'],
                            'pedido_id': pedidoId,
                            'total_pedido_padre': totalPedidoActual,
                            'nombre': it['productos']['nombre'],
                            'precio': (it['productos']['precio'] as num).toInt(),
                            'notas': it['notas'],
                            'estado': p['estado'],
                          });
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(15),
                              child: Text('DETALLE DE CONSUMO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.separated(
                                itemCount: renglonesTicket.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = renglonesTicket[index];
                                  final bool listo = item['estado'] == 'servido' || item['estado'] == 'listo';
                                  
                                  return ListTile(
                                    leading: Icon(listo ? Icons.check_circle : Icons.timer, color: listo ? Colors.green : Colors.orange),
                                    title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(item['notas'] ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('\$${item['precio']}', style: const TextStyle(fontSize: 16)),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _eliminarItemIndividual(
                                            item['item_id'], 
                                            item['pedido_id'], 
                                            item['precio'], 
                                            item['total_pedido_padre']
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('\$$granTotal', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 15)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaCategorias(mesaSeleccionada: widget.numeroMesa))),
                              icon: const Icon(Icons.add),
                              label: const Text('AGREGAR'),
                            )
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                              onPressed: granTotal > 0 ? () => _dialogoCobrar(granTotal) : null,
                              icon: const Icon(Icons.payments),
                              label: const Text('COBRAR'),
                            )
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _marcarComoServido() async {
    await Supabase.instance.client
        .from('pedidos')
        .update({'estado': 'servido'})
        .eq('numero_mesa', widget.numeroMesa)
        .eq('estado', 'listo');
    setState(() {});
  }

  void _dialogoCobrar(int total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Total a pagar: \$$total\n¿Cómo paga el cliente?'),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.all(20),
        actions: [
          Column(
            children: [
              _botonPago('Efectivo', Colors.green, Icons.money),
              const SizedBox(height: 10),
              _botonPago('MercadoPago', Colors.blue, Icons.qr_code_scanner),
              const SizedBox(height: 10),
              _botonPago('Tarjeta', Colors.orange, Icons.credit_card),
            ],
          )
        ],
      ),
    );
  }

  Widget _botonPago(String metodo, Color color, IconData icono) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
        onPressed: () {
          Navigator.pop(context); 
          
          if (metodo == 'MercadoPago') {
            _prepararQRMozo(metodo); 
          } else {
            _ejecutarCobro(metodo); 
          }
        },
        icon: Icon(icono),
        label: Text(metodo, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ✨ MAGIA: Función súper rápida y limpia para mostrar solo la foto
  Future<void> _prepararQRMozo(String metodo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Center(child: Text('📲 Que el cliente escanee:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
        content: SingleChildScrollView( 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 250, 
                height: 250,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade200, width: 2)),
                child: Image.asset(
                  'assets/esquina.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        '⚠️ Falta el archivo\nesquina.jpg\nen carpeta assets',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20)),
            onPressed: () {
              Navigator.pop(context); 
              _ejecutarCobro(metodo); 
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('PAGO RECIBIDO', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _ejecutarCobro(String metodo) async {
    await Supabase.instance.client
        .from('pedidos')
        .update({'estado': 'cobrado', 'metodo_pago': metodo})
        .eq('numero_mesa', widget.numeroMesa)
        .neq('estado', 'cobrado'); 
    
    GestorCarrito.limpiar();
    
    if (!mounted) return;
    Navigator.pop(context); 
  }

  void _confirmarLimpiezaCuenta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Limpiar Cuenta?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('¿Está seguro de anular y limpiar los pedidos de esta mesa? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await Supabase.instance.client
                .from('pedidos')
                .update({'estado': 'archivado'})
                .eq('numero_mesa', widget.numeroMesa)
                .neq('estado', 'cobrado');
              
              GestorCarrito.limpiar(); 
              if (!mounted) return;
              Navigator.pop(context); 
              Navigator.pop(context); 
            }, 
            child: const Text('LIMPIAR MESA')
          )
        ],
      )
    );
  }
}