import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'productos_screen.dart'; // Importamos la pantalla que crearemos en el Paso 2

class PantallaCategorias extends StatelessWidget {
  final int mesaSeleccionada;
  
  const PantallaCategorias({super.key, required this.mesaSeleccionada});

  @override
  Widget build(BuildContext context) {
    // ✨ MODIFICACIÓN (Punto 1 & 5): Eliminamos la variable horaActual. 
    // Ahora solo filtramos por 'estado_activo' para ocultar las borradas por el dueño.

    final streamCategorias = Supabase.instance.client
        .from('categorias')
        .stream(primaryKey: ['id'])
        .eq('estado_activo', true) 
        .order('id');

    return Scaffold(
      appBar: AppBar(
        title: Text('MESA $mesaSeleccionada - Seleccionar Categoría', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.deepOrange,
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder(
        stream: streamCategorias,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          // ✨ MODIFICACIÓN: Ya no hay filtro de "categoriasDisponibles". Mostramos todas directo.
          final todasLasCategorias = snapshot.data as List<dynamic>? ?? [];

          if (todasLasCategorias.isEmpty) {
            return const Center(
              child: Text('🍽️ No hay categorías disponibles.', style: TextStyle(fontSize: 20, color: Colors.grey))
            );
          }

          // ✨ MODIFICACIÓN (Punto 10): Envolvemos el GridView en un SafeArea
          return SafeArea(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.3,
              ),
              itemCount: todasLasCategorias.length,
              itemBuilder: (context, index) {
                final cat = todasLasCategorias[index];
                
              return InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => PantallaProductos(
                        numeroMesa: mesaSeleccionada, 
                        categoriaId: cat['id'],
                        nombreCategoria: cat['nombre'],
                      )
                    ));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.deepOrange.shade200, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(2, 2))]
                    ),
                    child: Center(
                      child: Text(
                        cat['nombre'].toString().toUpperCase(), 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.deepOrange.shade900, fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}