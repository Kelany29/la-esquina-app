import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaAdminProductos extends StatefulWidget {
  const PantallaAdminProductos({super.key});

  @override
  State<PantallaAdminProductos> createState() => _PantallaAdminProductosState();
}

class _PantallaAdminProductosState extends State<PantallaAdminProductos> {
  // ✨ MODIFICACIÓN: Ahora le decimos a Supabase que traiga SOLO los productos que están activos
  final streamProductos = Supabase.instance.client
      .from('productos')
      .stream(primaryKey: ['id'])
      .eq('estado_activo', true) // <-- Acá filtramos los borrados lógicamente
      .order('categoria_id', ascending: true);

  List<dynamic> _categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarCategorias(); // Buscamos las categorías para el menú desplegable
  }

  Future<void> _cargarCategorias() async {
    final data = await Supabase.instance.client.from('categorias').select();
    setState(() {
      _categorias = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ GESTIÓN DE MENÚ Y STOCK', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.shade800, // Un color distinto para el área de Admin
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder(
        stream: streamProductos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final productos = snapshot.data as List<dynamic>? ?? [];

          if (productos.isEmpty) return const Center(child: Text('No hay productos en el menú.'));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final prod = productos[index];
              final stock = prod['stock'] ?? 0;
              final bool sinStock = stock <= 0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: sinStock ? Colors.red.shade300 : Colors.transparent, width: 2)
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: sinStock ? Colors.red.shade100 : Colors.deepPurple.shade100,
                    child: Icon(sinStock ? Icons.warning : Icons.fastfood, color: sinStock ? Colors.red : Colors.deepPurple),
                  ),
                  title: Text(prod['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(
                    'Precio: \$${prod['precio']}  |  Stock: $stock', 
                    style: TextStyle(color: sinStock ? Colors.red : Colors.grey.shade700, fontWeight: sinStock ? FontWeight.bold : FontWeight.normal)
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón EDITAR
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _mostrarFormularioProducto(productoExistente: prod),
                      ),
                      // Botón BORRAR
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _borrarProducto(prod['id'], prod['nombre']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // BOTÓN FLOTANTE PARA AGREGAR NUEVO
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple.shade800,
        foregroundColor: Colors.white,
        onPressed: () => _mostrarFormularioProducto(),
        icon: const Icon(Icons.add),
        label: const Text('NUEVO PLATO', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- EL FORMULARIO MÁGICO (Sirve para Crear y para Editar) ---
  void _mostrarFormularioProducto({Map<String, dynamic>? productoExistente}) {
    final bool esEdicion = productoExistente != null;
    
    // Controladores para leer lo que escribe el dueño
    final nombreController = TextEditingController(text: esEdicion ? productoExistente['nombre'] : '');
    final precioController = TextEditingController(text: esEdicion ? productoExistente['precio'].toString() : '');
    final stockController = TextEditingController(text: esEdicion ? (productoExistente['stock']?.toString() ?? '100') : '100');
    
    // Categoría predeterminada (si está editando usa esa, sino la primera de la lista)
    int? categoriaSeleccionada = esEdicion ? productoExistente['categoria_id'] : (_categorias.isNotEmpty ? _categorias.first['id'] : null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(esEdicion ? '✏️ Editar Producto' : '🍔 Nuevo Producto', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre del plato/bebida', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: precioController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Precio (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock actual', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Menú desplegable para elegir la categoría
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                    value: categoriaSeleccionada,
                    items: _categorias.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['id'],
                        child: Text(cat['nombre'].toString().toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (nuevoValor) {
                      setStateDialog(() => categoriaSeleccionada = nuevoValor);
                    },
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade800, foregroundColor: Colors.white),
                onPressed: () async {
                  // Guardamos o actualizamos en Supabase
                  final datosFormulario = {
                    'nombre': nombreController.text,
                    'precio': int.tryParse(precioController.text) ?? 0,
                    'stock': int.tryParse(stockController.text) ?? 0,
                    'categoria_id': categoriaSeleccionada,
                    'estado_activo': true, // Por las dudas, nos aseguramos de que nazca activo
                  };

                  if (esEdicion) {
                    await Supabase.instance.client.from('productos').update(datosFormulario).eq('id', productoExistente['id']);
                  } else {
                    await Supabase.instance.client.from('productos').insert(datosFormulario);
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(esEdicion ? '✅ Producto actualizado' : '✅ Producto creado'), backgroundColor: Colors.green));
                },
                child: Text(esEdicion ? 'GUARDAR CAMBIOS' : 'CREAR PRODUCTO'),
              )
            ],
          );
        }
      ),
    );
  }

  // ✨ LA MAGIA DEL SOFT DELETE: En vez de borrar, actualizamos el estado
 Future<void> _borrarProducto(int id, String nombre) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Eliminar Producto'),
        content: Text('¿Estás seguro que querés eliminar "$nombre" del menú?\n\n(No te preocupes, los tickets viejos de la caja seguirán intactos).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                // 🪄 El truco: Simplemente apagamos la luz de ese producto
                await Supabase.instance.client.from('productos').update({'estado_activo': false}).eq('id', id);
                
                if (!mounted) return;
                Navigator.pop(context); // Cerramos el diálogo
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Producto retirado del menú'), backgroundColor: Colors.green)
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Error al eliminar: $e'), backgroundColor: Colors.red)
                );
              }
            },
            child: const Text('SÍ, ELIMINAR'),
          )
        ],
      ),
    );
  }
}