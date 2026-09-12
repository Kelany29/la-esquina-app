import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PantallaVentasMozo extends StatefulWidget {
  final int mozoId;
  final String nombreMozo;

  const PantallaVentasMozo({super.key, required this.mozoId, required this.nombreMozo});

  @override
  State<PantallaVentasMozo> createState() => _PantallaVentasMozoState();
}

class _PantallaVentasMozoState extends State<PantallaVentasMozo> {
  final _supabase = Supabase.instance.client;
  DateTime _inicioTurno = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📊 Mis Ventas: ${widget.nombreMozo}'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: FutureBuilder(
          future: _supabase
              .from('pedidos')
              .select()
              .eq('mozo_id', widget.mozoId)
              .gte('created_at', _inicioTurno.toIso8601String())
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

            final misPedidos = snapshot.data as List<dynamic>? ?? [];
            
            int totalGenerado = 0;
            int mesasCobradas = 0;
            int mesasAbiertas = 0;

            for (var p in misPedidos) {
              int monto = (p['total'] as num).toInt();
              totalGenerado += monto;
              
              if (p['estado'] == 'cobrado' || p['estado'] == 'archivado') {
                mesasCobradas++;
              } else {
                mesasAbiertas++;
              }
            }

            int ticketPromedio = misPedidos.isEmpty ? 0 : totalGenerado ~/ misPedidos.length;

            return Column(
              children: [
                // Panel Superior
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(bottom: BorderSide(color: Colors.blue.shade200, width: 2))
                  ),
                  child: Column(
                    children: [
                      const Text('DINERO GENERADO HOY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text('\$$totalGenerado', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    ],
                  ),
                ),

                // Tarjetas de Métricas
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TarjetaMetrica(titulo: 'MESAS TOTALES', valor: '${misPedidos.length}', icono: Icons.table_restaurant)
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TarjetaMetrica(titulo: 'PROMEDIO', valor: '\$$ticketPromedio', icono: Icons.receipt_long)
                      ),
                    ],
                  ),
                ),

                // Lista de pedidos
                Expanded(
                  child: misPedidos.isEmpty
                      ? const Center(child: Text('Todavía no cargaste pedidos hoy.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                      : ListView.builder(
                          itemCount: misPedidos.length,
                          itemBuilder: (context, index) {
                            final pedido = misPedidos[index];
                            final esCobrado = pedido['estado'] == 'cobrado' || pedido['estado'] == 'archivado';
                            final hora = DateTime.parse(pedido['created_at']).toLocal();
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esCobrado ? Colors.green.shade100 : Colors.orange.shade100,
                                child: Icon(esCobrado ? Icons.check : Icons.timer, color: esCobrado ? Colors.green : Colors.orange),
                              ),
                              title: Text('Mesa ${pedido['numero_mesa']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(DateFormat('HH:mm').format(hora)),
                              trailing: Text('\$${pedido['total']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            );
                          },
                        ),
                ),

                // Botón Cierre de Turno
                Container(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: mesasAbiertas > 0 ? null : () => _confirmarCierreMozo(),
                    icon: const Icon(Icons.stop_circle), 
                    label: Text(mesasAbiertas > 0 ? 'HAY MESAS ABIERTAS' : 'CERRAR MI TURNO', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmarCierreMozo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Turno'),
        content: const Text('Tus contadores de ventas volverán a cero para tu próximo turno. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _inicioTurno = DateTime.now(); // Reinicia el filtro de fecha a ESTE MOMENTO
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno finalizado. ¡Buen descanso!')));
            }, 
            child: const Text('SÍ, CERRAR')
          )
        ],
      )
    );
  }
}

class _TarjetaMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;

  const _TarjetaMetrica({required this.titulo, required this.valor, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: Colors.blue, size: 24),
          const SizedBox(height: 10),
          Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
        ],
      ),
    );
  }
}