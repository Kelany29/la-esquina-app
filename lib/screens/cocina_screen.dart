import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaCocina extends StatelessWidget {
  const PantallaCocina({super.key});

  @override
  Widget build(BuildContext context) {
    final streamPedidos = Supabase.instance.client
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('👨‍🍳 TABLERO DE COCINA'),
        backgroundColor: Colors.blueGrey.shade800, 
        foregroundColor: Colors.white,
        // ✨ MODIFICACIÓN PUNTO 1: Botón de salida para el Cocinero
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('🚪 Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('¿Estás seguro que querés salir del Tablero de Cocina?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      onPressed: () {
                        // Cierra el diálogo y luego saca al usuario a la pantalla de Login
                        Navigator.pop(context);
                        Navigator.pop(context); // Esto asume que entraste a la cocina haciendo un "push" desde el login.
                      },
                      child: const Text('SALIR'),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder(
        stream: streamPedidos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final todosLosPedidos = snapshot.data as List<dynamic>;

          // --- MAGIA 1: Filtramos lo cobrado, lo entregado, las bebidas Y LO ARCHIVADO ---
          final pedidosActivos = todosLosPedidos.where((p) {
            final estado = p['estado'].toString().toLowerCase(); 
            return estado != 'entregado' && 
                   estado != 'cobrado' &&
                   estado != 'servido' && 
                   estado != 'archivado'; 
          }).toList();

          if (pedidosActivos.isEmpty) {
            return const Center(
              child: Text('🍽️ Cocina limpia.\n¡No hay pedidos pendientes!', 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 22, color: Colors.grey)
              )
            );
          }

          return ListView.builder(
            itemCount: pedidosActivos.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final pedido = pedidosActivos[index];
              final pedidoId = pedido['id']; 
              final estadoPedido = pedido['estado'].toString().toLowerCase();
              
              Color colorEstado = Colors.grey;
              IconData iconoEstado = Icons.receipt;
              
              if (estadoPedido == 'enviado a cocina' || estadoPedido == 'preparando') { colorEstado = Colors.orange; iconoEstado = Icons.notifications_active; }
              if (estadoPedido == 'en preparacion') { colorEstado = Colors.blue; iconoEstado = Icons.soup_kitchen; }
              if (estadoPedido == 'listo') { colorEstado = Colors.green; iconoEstado = Icons.room_service; }

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(side: BorderSide(color: colorEstado, width: 2), borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mesa ${pedido['numero_mesa']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          Chip(
                            avatar: Icon(iconoEstado, color: Colors.white, size: 18),
                            label: Text(pedido['estado'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: colorEstado,
                          )
                        ],
                      ),
                      const Divider(),
                      
                      const Text('Platos a preparar:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 5),

                      FutureBuilder(
                        future: Supabase.instance.client
                            .from('pedido_items')
                            .select('cantidad, notas, productos(nombre)') 
                            .eq('pedido_id', pedidoId),
                        builder: (context, snapshotItems) {
                          if (snapshotItems.connectionState == ConnectionState.waiting) {
                            return const Text('Leyendo ticket...', style: TextStyle(fontStyle: FontStyle.italic));
                          }
                          if (snapshotItems.hasError) return const Text('Error al leer platos');
                          
                          final items = snapshotItems.data as List<dynamic>? ?? [];
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: items.map<Widget>((item) {
                              final cantidad = item['cantidad'];
                              final nombrePlato = item['productos'] != null ? item['productos']['nombre'] : 'Producto eliminado';
                              
                              final notaTexto = (item['notas'] != null && item['notas'].toString().isNotEmpty) 
                                  ? item['notas'].toString() 
                                  : '';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w500),
                                    children: [
                                      TextSpan(text: '• $cantidad x $nombrePlato'),
                                      if (notaTexto.isNotEmpty) 
                                        TextSpan(
                                          text: '\n   📝 Nota: $notaTexto', 
                                          style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 15),
                      const Divider(),
                      Text('Pedido #$pedidoId - Total: \$${pedido['total']}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 15),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (estadoPedido == 'enviado a cocina' || estadoPedido == 'preparando')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              onPressed: () => cambiarEstado(pedidoId, 'en preparacion'),
                              icon: const Icon(Icons.local_fire_department), label: const Text('PREPARAR'),
                            ),
                          if (estadoPedido == 'en preparacion')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => cambiarEstado(pedidoId, 'listo'),
                              icon: const Icon(Icons.check_circle), label: const Text('MARCAR LISTO'),
                            ),
                          if (estadoPedido == 'listo')
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              onPressed: () => cambiarEstado(pedidoId, 'servido'), 
                              icon: const Icon(Icons.send), label: const Text('ENTREGAR AL MOZO'),
                            ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> cambiarEstado(int id, String nuevoEstado) async {
    await Supabase.instance.client
        .from('pedidos')
        .update({'estado': nuevoEstado})
        .eq('id', id);
  }
}