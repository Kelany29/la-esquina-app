import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaAdminPersonal extends StatefulWidget {
  const PantallaAdminPersonal({super.key});

  @override
  State<PantallaAdminPersonal> createState() => _PantallaAdminPersonalState();
}

class _PantallaAdminPersonalState extends State<PantallaAdminPersonal> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 GESTIÓN DE PERSONAL', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase.from('usuarios').stream(primaryKey: ['id']).eq('activo', true).order('rol'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

            final empleados = snapshot.data ?? [];

            if (empleados.isEmpty) {
              return const Center(child: Text('No hay personal activo.', style: TextStyle(fontSize: 18, color: Colors.grey)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: empleados.length,
              itemBuilder: (context, index) {
                final emp = empleados[index];
                final bool estaActivo = emp['activo'] ?? true;
                final String rol = emp['rol'].toString().toUpperCase();
                
                // ✨ MODIFICACIÓN PUNTO 3: Enmascarar PIN si es Administrador
                final String pinMostrado = rol == 'ADMIN' ? '****' : emp['pin'].toString();

                return Card(
                  elevation: 2,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepOrange, 
                      child: Icon(rol == 'ADMIN' ? Icons.security : (rol == 'COCINA' ? Icons.soup_kitchen : Icons.person), color: Colors.white)
                    ),
                    title: Text('${emp['nombre']} ($rol)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    // Mostramos la variable segura en lugar del dato crudo
                    subtitle: Text('PIN: $pinMostrado'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rol == 'MOZO') 
                          IconButton(
                            icon: const Icon(Icons.bar_chart, color: Colors.blue),
                            tooltip: 'Ver Desempeño',
                            onPressed: () => _mostrarEstadisticas(emp['id'], emp['nombre']),
                          ),
                        Switch(
                          value: estaActivo,
                          activeColor: Colors.green,
                          onChanged: (valor) async {
                            bool confirmar = await _mostrarConfirmacionBaja(context, emp['nombre']);
                            if (confirmar) {
                              await _supabase.from('usuarios').update({'activo': false}).eq('id', emp['id']);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('NUEVO EMPLEADO'),
        onPressed: () => _mostrarDialogoNuevoEmpleado(),
      ),
    );
  }

  Future<bool> _mostrarConfirmacionBaja(BuildContext context, String nombre) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Dar de baja'),
        content: Text('¿Seguro que querés desactivar a $nombre? Ya no podrá iniciar sesión y desaparecerá de esta lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('DESACTIVAR')
          )
        ],
      )
    ) ?? false;
  }

  void _mostrarDialogoNuevoEmpleado() {
    final nombreController = TextEditingController();
    final pinController = TextEditingController();
    String rolSeleccionado = 'mozo';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Alta de Personal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre del empleado', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: 'PIN de acceso (4 números)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                  value: rolSeleccionado,
                  items: const [
                    DropdownMenuItem(value: 'mozo', child: Text('Mozo')),
                    DropdownMenuItem(value: 'cocina', child: Text('Cocina')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador / Dueño')),
                  ],
                  onChanged: (val) => setStateDialog(() => rolSeleccionado = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                onPressed: () async {
                  if (nombreController.text.isEmpty || pinController.text.length != 4) return;
                  
                  await _supabase.from('usuarios').insert({
                    'nombre': nombreController.text,
                    'pin': pinController.text,
                    'rol': rolSeleccionado,
                    'activo': true,
                  });
                  
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('GUARDAR'),
              )
            ],
          );
        }
      ),
    );
  }

  void _mostrarEstadisticas(int mozoId, String nombreMozo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📊 Desempeño: $nombreMozo'),
        content: FutureBuilder(
          future: _supabase.from('pedidos').select('total').eq('mozo_id', mozoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            if (snapshot.hasError) return Text('Error: ${snapshot.error}');

            final pedidos = snapshot.data as List<dynamic>? ?? [];
            
            int totalRecaudado = 0;
            for (var p in pedidos) {
              totalRecaudado += (p['total'] as num).toInt();
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.table_restaurant, color: Colors.deepOrange, size: 40),
                  title: const Text('Mesas Atendidas', style: TextStyle(color: Colors.grey)),
                  subtitle: Text('${pedidos.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.monetization_on, color: Colors.green, size: 40),
                  title: const Text('Dinero Generado', style: TextStyle(color: Colors.grey)),
                  subtitle: Text('\$$totalRecaudado', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}