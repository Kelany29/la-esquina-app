import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalle_mesa_screen.dart'; 
import 'cocina_screen.dart'; 
import 'caja_screen.dart'; 
import 'admin_productos_screen.dart';
import 'login_screen.dart'; 
import 'categorias_screen.dart';
import '../main.dart' hide PantallaCategorias; 
import 'admin_insumos_screen.dart';
import 'admin_recetas_screen.dart';
import 'admin_personal_screen.dart';
import 'tablero_screen.dart'; 
import 'ventas_mozo_screen.dart'; 

class PantallaMesas extends StatefulWidget {
  final String rolUsuario; 
  
  const PantallaMesas({super.key, required this.rolUsuario});

  @override
  State<PantallaMesas> createState() => _PantallaMesasState();
}

class _PantallaMesasState extends State<PantallaMesas> {
  late final Stream<List<Map<String, dynamic>>> _streamMesas;
  
  List<int> _mesasYaNotificadas = [];

  // ✨ MODIFICACIÓN: Agregamos la BARRA con IDs "ocultos" (101, 102, 103)
  final List<Map<String, dynamic>> zonasDelLocal = [
    {
      'nombre': 'SALÓN PRINCIPAL', 
      'mesas': List.generate(25, (i) => i + 1), // Mesas del 1 al 25
      'icono': Icons.restaurant
    },
    {
      'nombre': 'VEREDA', 
      'mesas': List.generate(15, (i) => i + 26), // Mesas del 26 al 40
      'icono': Icons.storefront
    },
    {
      'nombre': 'PATIO', 
      'mesas': List.generate(15, (i) => i + 41), // Mesas del 41 al 55
      'icono': Icons.park
    },
    {
      'nombre': 'LA BARRA', 
      'mesas': [101, 102, 103], // 🚨 Banquetas B1, B2 y B3
      'icono': Icons.local_bar
    },
  ];

  @override
  void initState() {
    super.initState();
    _streamMesas = Supabase.instance.client
        .from('pedidos')
        .stream(primaryKey: ['id']);
  }

  void _cerrarSesion() {
    SesionGlobal.cerrarSesion(); 
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaLogin()));
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = widget.rolUsuario == 'admin';

    return DefaultTabController(
      length: zonasDelLocal.length, 
      child: Scaffold(
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Colors.black87),
                  accountName: Text(SesionGlobal.nombreUsuarioActual ?? 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  accountEmail: Text('Rol: ${widget.rolUsuario.toUpperCase()}'),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.deepOrange,
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                ),
                
                if (esAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.point_of_sale, color: Colors.green),
                    title: const Text('Caja y Finanzas', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context); 
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaCaja()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.analytics, color: Colors.purple),
                    title: const Text('Tablero del Jefe', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaTablero())); 
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.soup_kitchen, color: Colors.orange),
                    title: const Text('Monitor de Cocina'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaCocina()));
                    },
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.only(left: 15, top: 10, bottom: 10),
                    child: Text('⚙️ ADMINISTRACIÓN', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book),
                    title: const Text('Gestión de Menú'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaAdminProductos()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory),
                    title: const Text('Control de Insumos'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaAdminInsumos()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.blender),
                    title: const Text('Gestor de Recetas'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaAdminRecetas()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Personal'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaAdminPersonal()));
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.bar_chart, color: Colors.blue),
                    title: const Text('Mis Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Tu rendimiento del turno'),
                    onTap: () {
                      Navigator.pop(context); 
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaVentasMozo(
                        mozoId: SesionGlobal.idUsuarioActual ?? 0, 
                        nombreMozo: SesionGlobal.nombreUsuarioActual ?? 'Mozo'
                      )));
                    },
                  ),
                ], 
                
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: _cerrarSesion,
                ),
              ],
            ),
          ),
        ),
        
        appBar: AppBar(
          title: const Text('🔥 LA ESQUINA', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black87, 
          foregroundColor: Colors.deepOrange, 
          bottom: TabBar(
            isScrollable: true, 
            indicatorColor: Colors.deepOrange,
            indicatorWeight: 4,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            tabs: zonasDelLocal.map((zona) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(zona['icono'] ?? Icons.circle, size: 20),
                  const SizedBox(width: 8),
                  Text(zona['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            )).toList(),
          ),
        ),
        backgroundColor: Colors.grey.shade100,
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _streamMesas, 
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.deepOrange));
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            
            final todosLosPedidos = snapshot.data ?? [];
            
            final pedidosActivos = todosLosPedidos.where((p) {
              final estado = p['estado'].toString().toLowerCase();
              return estado != 'cobrado' && estado != 'archivado';
            }).toList();
            
            final mesasOcupadas = <int>{};
            final mesasConComidaLista = <int>{};

            for (var p in pedidosActivos) {
              mesasOcupadas.add(p['numero_mesa']);
              if (p['estado'].toString().toLowerCase() == 'listo') {
                mesasConComidaLista.add(p['numero_mesa']); 
              }
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              final listaNueva = mesasConComidaLista.toList();
              bool nuevaAlertaDetectada = false;
              
              for (var mesa in listaNueva) {
                if (!_mesasYaNotificadas.contains(mesa)) {
                  nuevaAlertaDetectada = true;
                  break;
                }
              }

              if (nuevaAlertaDetectada) {
                HapticFeedback.heavyImpact(); 
              }
              _mesasYaNotificadas = listaNueva; 
            });

            return SafeArea(
              child: Column(
                children: [
                  if (mesasConComidaLista.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                      color: Colors.amber,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_active, size: 30, color: Colors.black87),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              // ✨ TRUCO VISUAL EN LA ALERTA: Filtramos si hay una banqueta en la lista de comidas listas
                              '¡ATENCIÓN! Retirar pedido en cocina - ${mesasConComidaLista.map((m) => m > 100 ? 'Banqueta ${m - 100}B' : 'MESA $m').join(', ')}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: TabBarView(
                      children: zonasDelLocal.map((zona) {
                        final List<int> mesasDeEstaZona = zona['mesas'];

                        return GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, 
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                          itemCount: mesasDeEstaZona.length, 
                          itemBuilder: (context, index) {
                            final numeroMesa = mesasDeEstaZona[index]; 
                            final estaOcupada = mesasOcupadas.contains(numeroMesa);
                            final comidaLista = mesasConComidaLista.contains(numeroMesa); 

                            Color colorFondo = comidaLista ? Colors.amber.shade300 : (estaOcupada ? Colors.deepOrange.shade50 : Colors.white);
                            Color colorBorde = comidaLista ? Colors.amber.shade900 : (estaOcupada ? Colors.deepOrange : Colors.grey.shade300);

                            // ✨ TRUCO VISUAL EN EL BOTÓN: Cambiamos el texto e ícono si es una Banqueta
                            final esBanqueta = numeroMesa > 100;
                            final textoMesa = esBanqueta ? 'BANQUETA ${numeroMesa - 100}B' : 'MESA $numeroMesa';
                            final iconoMesa = esBanqueta ? Icons.chair_alt : (comidaLista ? Icons.notifications_active : (estaOcupada ? Icons.local_dining : Icons.table_restaurant));

                            return InkWell(
                              onTap: () {
                                if (estaOcupada) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaDetalleMesa(numeroMesa: numeroMesa)));
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaCategorias(mesaSeleccionada: numeroMesa)));
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorFondo,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: colorBorde, width: estaOcupada ? 3 : 1),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(2, 2))]
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      iconoMesa, 
                                      size: 40, 
                                      color: comidaLista ? Colors.black87 : (estaOcupada ? Colors.deepOrange : Colors.grey.shade400)
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      textoMesa, // Usamos nuestra variable calculada
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: comidaLista ? Colors.black87 : (estaOcupada ? Colors.deepOrange.shade900 : Colors.black54)),
                                    ),
                                    Text(
                                      comidaLista ? '¡Retirar!' : (estaOcupada ? 'Ocupada' : 'Libre'),
                                      style: TextStyle(color: comidaLista ? Colors.black87 : (estaOcupada ? Colors.deepOrange : Colors.grey), fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}