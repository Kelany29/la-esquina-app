import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaAdminRecetas extends StatefulWidget {
  const PantallaAdminRecetas({super.key});

  @override
  State<PantallaAdminRecetas> createState() => _PantallaAdminRecetasState();
}

class _PantallaAdminRecetasState extends State<PantallaAdminRecetas> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _insumosDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarInsumos();
  }

  Future<void> _cargarInsumos() async {
    final data = await _supabase.from('insumos').select().order('nombre');
    setState(() {
      _insumosDisponibles = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍳 GESTOR DE RECETAS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder(
        future: _supabase.from('productos').select().eq('estado_activo', true).order('categoria_id'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final productos = snapshot.data as List<dynamic>? ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final prod = productos[index];
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.restaurant, color: Colors.white)),
                  title: Text(prod['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Tocar para configurar receta'),
                  trailing: const Icon(Icons.edit_note, color: Colors.blueGrey),
                  onTap: () => _mostrarPanelReceta(prod['id'], prod['nombre']),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarPanelReceta(int productoId, String nombreProducto) {
    int? insumoSeleccionado;
    String unidadSeleccionadaReceta = 'Gramos (g)';
    int? idIngredienteAEditar; 
    
    final cantidadController = TextEditingController();
    final List<String> unidadesReceta = ['Unidades (u)', 'Gramos (g)', 'Kilogramos (kg)', 'Litros (L)', 'Mililitros (ml)'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      useSafeArea: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          final double espacioTeclado = MediaQuery.of(context).viewInsets.bottom;
          final bool esEdicionIngrediente = idIngredienteAEditar != null;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))
            ),
            padding: EdgeInsets.only(bottom: espacioTeclado, left: 20, right: 20, top: 20),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receta de: $nombreProducto', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const Divider(thickness: 2),
                    
                    const Text('Ingredientes actuales:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    SizedBox(
                      height: 160, 
                      child: StreamBuilder(
                        stream: _supabase.from('recetas').stream(primaryKey: ['id']).eq('producto_id', productoId),
                        builder: (context, snapshotReceta) {
                          if (!snapshotReceta.hasData) return const Center(child: CircularProgressIndicator());
                          
                          final ingredientes = snapshotReceta.data as List<dynamic>;
                          if (ingredientes.isEmpty) return const Center(child: Text('Este producto no descuenta stock.'));

                          return ListView.builder(
                            itemCount: ingredientes.length,
                            itemBuilder: (context, index) {
                              final ing = ingredientes[index];
                              final insumoLocal = _insumosDisponibles.firstWhere((i) => i['id'] == ing['insumo_id'], orElse: () => {'nombre': 'Desconocido', 'unidad_medida': ''});

                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.kitchen, size: 20),
                                title: Text(insumoLocal['nombre']),
                                subtitle: Text('Gasta: ${ing['cantidad_necesaria']} ${ing['unidad_medida_receta'] ?? ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                      onPressed: () {
                                        setStateModal(() {
                                          idIngredienteAEditar = ing['id'];
                                          insumoSeleccionado = ing['insumo_id'];
                                          cantidadController.text = ing['cantidad_necesaria'].toString();
                                          if (ing['unidad_medida_receta'] != null && unidadesReceta.contains(ing['unidad_medida_receta'])) {
                                            unidadSeleccionadaReceta = ing['unidad_medida_receta'];
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () async {
                                        // ✨ SEGURIDAD: Try/Catch en el borrado
                                        try {
                                          await _supabase.from('recetas').delete().eq('id', ing['id']);
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar: $e'), backgroundColor: Colors.red));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    
                    Text(esEdicionIngrediente ? '✏️ Modificar Ingrediente:' : '➕ Añadir ingrediente:', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Seleccionar Insumo', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                      value: insumoSeleccionado,
                      isExpanded: true,
                      items: _insumosDisponibles.map((insumo) {
                        return DropdownMenuItem<int>(
                          value: insumo['id'],
                          child: Text('${insumo['nombre']} (Stock en: ${insumo['unidad_medida']})'),
                        );
                      }).toList(),
                      onChanged: (val) => setStateModal(() => insumoSeleccionado = val),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: cantidadController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Cantidad'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: unidadSeleccionadaReceta,
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Medida', contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                            items: unidadesReceta.map((String uni) {
                              return DropdownMenuItem<String>(
                                value: uni,
                                child: Text(uni, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (String? nuevoValor) {
                              setStateModal(() {
                                unidadSeleccionadaReceta = nuevoValor!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: esEdicionIngrediente ? Colors.blue.shade800 : Colors.green, 
                          foregroundColor: Colors.white, 
                          padding: const EdgeInsets.all(15)
                        ),
                        onPressed: () async {
                          if (insumoSeleccionado == null || cantidadController.text.trim().isEmpty) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Faltan datos.'), backgroundColor: Colors.red));
                             return;
                          }
                          
                          final dataInsumoReceta = {
                            'producto_id': productoId,
                            'insumo_id': insumoSeleccionado,
                            'cantidad_necesaria': double.tryParse(cantidadController.text.replaceAll(',', '.')) ?? 0.0,
                            'unidad_medida_receta': unidadSeleccionadaReceta, 
                          };

                          // ✨ SEGURIDAD: Try/Catch en la actualización y guardado
                          try {
                            if (esEdicionIngrediente) {
                              await _supabase.from('recetas').update(dataInsumoReceta).eq('id', idIngredienteAEditar!);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Actualizado con éxito'), backgroundColor: Colors.green));
                            } else {
                              await _supabase.from('recetas').insert(dataInsumoReceta);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Guardado con éxito'), backgroundColor: Colors.green));
                            }
                            
                            cantidadController.clear();
                            setStateModal(() {
                              insumoSeleccionado = null;
                              idIngredienteAEditar = null;
                              unidadSeleccionadaReceta = 'Gramos (g)';
                            });
                            
                          } catch (e) {
                            if (!context.mounted) return;
                            // ESTE ES EL CARTEL QUE NOS SALVARÁ LA VIDA
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR GRAVE: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
                          }
                        },
                        child: Text(esEdicionIngrediente ? 'ACTUALIZAR INGREDIENTE' : 'GUARDAR INGREDIENTE', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}