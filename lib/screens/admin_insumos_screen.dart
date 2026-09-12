import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaAdminInsumos extends StatefulWidget {
  const PantallaAdminInsumos({super.key});

  @override
  State<PantallaAdminInsumos> createState() => _PantallaAdminInsumosState();
}

class _PantallaAdminInsumosState extends State<PantallaAdminInsumos> {
  final streamInsumos = Supabase.instance.client
      .from('insumos')
      .stream(primaryKey: ['id'])
      .order('nombre');

  // ✨ NUEVO: Lista fija de unidades para el Dropdown
  final List<String> unidadesPermitidas = ['Kilos (kg)', 'Gramos (g)', 'Litros (L)', 'Mililitros (ml)', 'Unidades (u)'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📦 CONTROL DE INSUMOS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder(
        stream: streamInsumos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final insumos = snapshot.data as List<dynamic>? ?? [];

          if (insumos.isEmpty) return const Center(child: Text('No hay insumos cargados en el depósito.'));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: insumos.length,
            itemBuilder: (context, index) {
              final insumo = insumos[index];
              final stock = insumo['stock_actual'] ?? 0;
              final minimo = insumo['stock_minimo'] ?? 0;
              final unidad = insumo['unidad_medida'] ?? '';
              
              final bool stockCritico = stock <= minimo;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: stockCritico ? Colors.red.shade400 : Colors.transparent, width: 2)
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: stockCritico ? Colors.red.shade100 : Colors.blueGrey.shade100,
                    child: Icon(stockCritico ? Icons.warning : Icons.inventory_2, color: stockCritico ? Colors.red : Colors.blueGrey),
                  ),
                  title: Text(insumo['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(
                    'Stock: $stock $unidad  |  Alerta en: $minimo $unidad',
                    style: TextStyle(color: stockCritico ? Colors.red : Colors.grey.shade700, fontWeight: stockCritico ? FontWeight.bold : FontWeight.normal)
                  ),
                  // ✨ MODIFICACIÓN: Agregamos el botón de Editar al lado del de Borrar
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Editar Insumo',
                        onPressed: () => _mostrarFormularioInsumo(insumoAEditar: insumo),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Borrar Insumo',
                        onPressed: () => _borrarInsumo(insumo['id'], insumo['nombre']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        onPressed: () => _mostrarFormularioInsumo(),
        icon: const Icon(Icons.add),
        label: const Text('NUEVO INSUMO', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ✨ MODIFICACIÓN: Formulario inteligente. Si le pasamos un insumo, es Editar. Si no, es Crear.
  void _mostrarFormularioInsumo({Map<String, dynamic>? insumoAEditar}) {
    final bool esEdicion = insumoAEditar != null;
    
    final nombreController = TextEditingController(text: esEdicion ? insumoAEditar['nombre'] : '');
    final stockController = TextEditingController(text: esEdicion ? insumoAEditar['stock_actual'].toString() : '');
    final minimoController = TextEditingController(text: esEdicion ? insumoAEditar['stock_minimo'].toString() : '');
    
    // Si estamos editando y la unidad existe en nuestra lista, la usamos. Si no, default a Kilos.
    String unidadSeleccionada = 'Kilos (kg)';
    if (esEdicion && unidadesPermitidas.contains(insumoAEditar['unidad_medida'])) {
      unidadSeleccionada = insumoAEditar['unidad_medida'];
    }

    showDialog(
      context: context,
      barrierDismissible: false, // Obliga a tocar los botones
      builder: (context) => StatefulBuilder( // Necesitamos esto para que el Dropdown cambie visualmente
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(esEdicion ? '✏️ Editar Insumo' : '📦 Cargar Insumo', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre (Ej: Huevos, Harina)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: stockController, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                          decoration: const InputDecoration(labelText: 'Stock Actual', border: OutlineInputBorder())
                        )
                      ),
                      const SizedBox(width: 10),
                      // ✨ NUEVO: El Menú Desplegable de Unidades
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: unidadSeleccionada,
                          decoration: const InputDecoration(labelText: 'Unidad', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                          items: unidadesPermitidas.map((String uni) {
                            return DropdownMenuItem<String>(
                              value: uni,
                              child: Text(uni, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (String? nuevoValor) {
                            setStateDialog(() {
                              unidadSeleccionada = nuevoValor!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: minimoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Alerta de stock mínimo', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade900, foregroundColor: Colors.white),
                onPressed: () async {
                  // ✨ VALIDACIÓN: Evitamos que guarden si dejaron campos vacíos
                  if (nombreController.text.trim().isEmpty || stockController.text.isEmpty || minimoController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⚠️ Por favor, completá todos los campos.'), backgroundColor: Colors.red)
                    );
                    return;
                  }

                  final dataAGuardar = {
                    'nombre': nombreController.text.trim(),
                    'stock_actual': double.tryParse(stockController.text.replaceAll(',', '.')) ?? 0.0,
                    'stock_minimo': double.tryParse(minimoController.text.replaceAll(',', '.')) ?? 0.0,
                    'unidad_medida': unidadSeleccionada,
                  };

                  try {
                    if (esEdicion) {
                      // Actualiza el existente
                      await Supabase.instance.client.from('insumos').update(dataAGuardar).eq('id', insumoAEditar['id']);
                    } else {
                      // Inserta uno nuevo
                      await Supabase.instance.client.from('insumos').insert(dataAGuardar);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
                  }
                },
                child: const Text('GUARDAR'),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _borrarInsumo(int id, String nombre) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Borrar Insumo'),
        content: Text('¿Seguro que querés eliminar "$nombre"? Si borrás este insumo, las recetas que lo usen van a fallar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await Supabase.instance.client.from('insumos').delete().eq('id', id);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('BORRAR'),
          )
        ],
      ),
    );
  }
}