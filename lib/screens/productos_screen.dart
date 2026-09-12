import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import 'login_screen.dart'; // ✨ IMPORTACIÓN NECESARIA PARA SABER QUIÉN ES EL MOZO/ADMIN

// El "Cerebro" global que mantiene los pedidos vivos entre categorías
class GestorCarrito {
  static int mesaActual = -1;
  static List<Map<String, dynamic>> items = [];

  static void configurarMesa(int numeroMesa) {
    if (mesaActual != numeroMesa) {
      mesaActual = numeroMesa;
      items = [];
    }
  }

  static void limpiar() {
    items = [];
  }
}

class PantallaProductos extends StatefulWidget {
  final int categoriaId;
  final dynamic nombreCategoria; 
  final int numeroMesa; 

  const PantallaProductos({
    super.key, 
    required this.categoriaId, 
    required this.nombreCategoria,
    required this.numeroMesa 
  });

  @override
  State<PantallaProductos> createState() => _PantallaProductosState();
}

class _PantallaProductosState extends State<PantallaProductos> {
  List<dynamic> _adicionalesDisponibles = [];

  @override
  void initState() {
    super.initState();
    GestorCarrito.configurarMesa(widget.numeroMesa); 
    _cargarAdicionales(); 
  }

  Future<void> _cargarAdicionales() async {
    final data = await Supabase.instance.client
        .from('adicionales')
        .select()
        .eq('categoria_id', widget.categoriaId);
    setState(() {
      _adicionalesDisponibles = data;
    });
  }

  int get totalPlata {
    int suma = 0;
    for (var item in GestorCarrito.items) {
      suma += (item['precio'] as num).toInt();
    }
    return suma;
  }

  @override
  Widget build(BuildContext context) {
    final futureProductos = Supabase.instance.client
        .from('productos')
        .select()
        .eq('categoria_id', widget.categoriaId)
        .eq('estado_activo', true); 

    final tituloSeguro = widget.nombreCategoria?.toString().toUpperCase() ?? 'CATEGORÍA';
    final bool esBebida = tituloSeguro.contains('BEBIDA');

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('MESA ${widget.numeroMesa} - $tituloSeguro', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.black87, 
          foregroundColor: Colors.deepOrange,
          centerTitle: true,
          elevation: 0,
        ),
        backgroundColor: Colors.grey.shade100, 
        body: FutureBuilder(
          future: futureProductos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            
            final productos = snapshot.data as List<dynamic>? ?? [];

            if (productos.isEmpty) return const Center(child: Text('No hay productos disponibles en esta categoría.'));

            return ListView.builder(
              itemCount: productos.length,
              padding: const EdgeInsets.only(bottom: 280, top: 10), 
              itemBuilder: (context, index) {
                final prod = productos[index];
                final nombreProd = prod['nombre']?.toString() ?? 'Producto sin nombre';
                final precioProd = prod['precio']?.toString() ?? '0';

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    title: Text(nombreProd, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('Precio: \$$precioProd', style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.deepOrange, size: 35),
                      onPressed: () => _mostrarDialogoConfigurarPlato(prod, nombreProd, precioProd),
                    ),
                  ),
                );
              },
            );
          },
        ),
        
        bottomSheet: GestorCarrito.items.isEmpty 
          ? const SizedBox.shrink() 
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🛒 DETALLE DEL PEDIDO ANTES DE ENVIAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180), 
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: GestorCarrito.items.length,
                        itemBuilder: (context, index) {
                          final item = GestorCarrito.items[index];
                          final bool tieneNotas = item['notas'] != null && item['notas'].toString().isNotEmpty;

                          return Card(
                            elevation: 0,
                            color: Colors.grey.shade50,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              dense: true,
                              title: Text(item['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                '\$${item['precio']} ${tieneNotas ? '\n📝 ${item['notas']}' : ''}', 
                                style: TextStyle(color: tieneNotas ? Colors.deepOrange.shade900 : Colors.black54, fontSize: 13)
                              ),
                              isThreeLine: tieneNotas,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Eliminar producto',
                                onPressed: () {
                                  setState(() {
                                    GestorCarrito.items.removeAt(index); 
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const Divider(height: 20, thickness: 2),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${GestorCarrito.items.length} items (Mesa ${widget.numeroMesa})', style: const TextStyle(color: Colors.grey)),
                            Text('Total: \$$totalPlata', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: esBebida ? Colors.blue.shade700 : Colors.deepOrange, 
                            foregroundColor: Colors.white, 
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
                          ),
                          onPressed: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
                            );

                            try {
                              final resultado = await DatabaseService().guardarPedido(
                                mesa: widget.numeroMesa,
                                total: totalPlata,
                                productos: GestorCarrito.items, 
                                estado: esBebida ? 'servido' : 'preparando', 
                                // ✨ MODIFICACIÓN PUNTO 8: Pasamos el ID del usuario actual
                                mozoId: SesionGlobal.idUsuarioActual, 
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context); 
                              setState(() {
                                GestorCarrito.limpiar(); 
                              });

                              if (resultado == 'offline') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('📡 Sin conexión. Pedido guardado en la tablet.'), 
                                    backgroundColor: Colors.amber,
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(esBebida ? '🥤 ¡Bebidas agregadas a la cuenta!' : '🚀 ¡Pedido enviado a cocina!'), 
                                    backgroundColor: Colors.green
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              Navigator.pop(context); 
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: Text(esBebida ? 'AGREGAR A LA CUENTA' : 'ENVIAR A COCINA', style: const TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  void _mostrarDialogoConfigurarPlato(Map<String, dynamic> prod, String nombreProd, String precioProd) {
    int cantidad = 1;
    TextEditingController notaController = TextEditingController();
    List<Map<String, dynamic>> extrasSeleccionados = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          int precioBase = int.tryParse(precioProd) ?? 0;
          int precioExtras = extrasSeleccionados.fold(0, (sum, extra) => sum + (extra['precio'] as num).toInt());
          int precioFinalUnitario = precioBase + precioExtras;
          int precioFinalTotal = precioFinalUnitario * cantidad;

          return AlertDialog(
            title: Text('Agregar $nombreProd', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 30, color: Colors.deepOrange),
                        onPressed: cantidad > 1 ? () => setStateDialog(() => cantidad--) : null,
                      ),
                      Text('$cantidad', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 30, color: Colors.deepOrange),
                        onPressed: () => setStateDialog(() => cantidad++),
                      ),
                    ],
                  ),
                  const Divider(),
                  
                  TextField(
                    controller: notaController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (Ej: Sin sal, a punto)', 
                      border: OutlineInputBorder()
                    ),
                    maxLines: 2,
                  ),
                  
                  if (_adicionalesDisponibles.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    const Text('Adicionales:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Column(
                      children: _adicionalesDisponibles.map((extra) {
                        final bool estaSeleccionado = extrasSeleccionados.contains(extra);
                        return CheckboxListTile(
                          title: Text('${extra['nombre']} (+\$${extra['precio']})'),
                          value: estaSeleccionado,
                          activeColor: Colors.deepOrange,
                          onChanged: (bool? valor) {
                            setStateDialog(() {
                              if (valor == true) {
                                extrasSeleccionados.add(extra);
                              } else {
                                extrasSeleccionados.remove(extra);
                              }
                            });
                          },
                        );
                      }).toList(),
                    )
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                onPressed: () {
                  String notaFinalCocina = notaController.text;
                  if (extrasSeleccionados.isNotEmpty) {
                    final nombresExtras = extrasSeleccionados.map((e) => e['nombre']).join(', ');
                    notaFinalCocina += notaFinalCocina.isEmpty ? 'Extras: $nombresExtras' : ' | Extras: $nombresExtras';
                  }

                  setState(() {
                    for (int i = 0; i < cantidad; i++) {
                      Map<String, dynamic> itemConNota = Map.from(prod);
                      
                      itemConNota['nombre'] = nombreProd; 
                      itemConNota['precio'] = precioFinalUnitario; 
                      itemConNota['notas'] = notaFinalCocina;
                      
                      GestorCarrito.items.add(itemConNota); 
                    }
                  });
                  
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ $cantidad $nombreProd agregado/s al carrito'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: Text('AGREGAR (\$$precioFinalTotal)'),
              )
            ],
          );
        }
      ),
    );
  }
}