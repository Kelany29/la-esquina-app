import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/productos_screen.dart'; 
import 'screens/cocina_screen.dart';
import 'screens/caja_screen.dart';
import 'screens/tablero_screen.dart'; 
import 'screens/mesas_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); 
  
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL']!,
  anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
);
  
  runApp(const LaEsquinaApp());
}

class LaEsquinaApp extends StatelessWidget {
  const LaEsquinaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'La Esquina',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange), 
        useMaterial3: true,
      ),
     home: const PantallaLogin(),
    );
  }
}

class PantallaCategorias extends StatelessWidget {
  final int mesaSeleccionada; 

  const PantallaCategorias({super.key, required this.mesaSeleccionada}); 

  @override
  Widget build(BuildContext context) {
    final futureCategorias = Supabase.instance.client.from('categorias').select();

    return Scaffold(
      appBar: AppBar(
        title: Text('MENÚ - MESA $mesaSeleccionada', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87, 
        foregroundColor: Colors.deepOrange, 
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Estadísticas',
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const PantallaTablero())
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Ir a Caja',
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const PantallaCaja())
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.soup_kitchen),
            tooltip: 'Ir a Cocina',
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const PantallaCocina())
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: futureCategorias,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final datos = snapshot.data as List<dynamic>;

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 10, 
              mainAxisSpacing: 10,
            ),
            itemCount: datos.length,
            itemBuilder: (context, index) {
              final cat = datos[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => PantallaProductos(
                        categoriaId: cat['id'], 
                        nombreCategoria: cat['nombre'],
                        numeroMesa: mesaSeleccionada, // <-- ACÁ ENVIAMOS EL DATO A LOS PRODUCTOS
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50, 
                    borderRadius: BorderRadius.circular(15), 
                    border: Border.all(color: Colors.deepOrange.shade200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu, size: 40, color: Colors.deepOrange),
                      const SizedBox(height: 10),
                      Text(
                        cat['nombre'].toString().toUpperCase(), 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900),
                      ),
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
}