import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 

class PantallaTablero extends StatefulWidget {
  const PantallaTablero({super.key});

  @override
  State<PantallaTablero> createState() => _PantallaTableroState();
}

class _PantallaTableroState extends State<PantallaTablero> {
  DateTime _fechaInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fechaFin = DateTime.now();

  Future<void> _elegirFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.indigo.shade800)),
          child: child!,
        );
      },
    );

    if (rango != null) {
      setState(() {
        _fechaInicio = rango.start;
        _fechaFin = rango.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 TABLERO DEL JEFE', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100, 
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analizando periodo:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(
                      '${DateFormat('dd/MM/yy').format(_fechaInicio)} al ${DateFormat('dd/MM/yy').format(_fechaFin)}',
                      style: TextStyle(fontSize: 16, color: Colors.indigo.shade800, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo.shade800),
                  onPressed: _elegirFechas,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Filtrar'),
                )
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder(
              future: Supabase.instance.client
                  .from('pedidos')
                  .select('*, pedido_items(productos(nombre))') 
                  // ✨ MODIFICACIÓN PUNTO 5: Ahora suma lo archivado Y lo cobrado en el momento
                  .or('estado.eq.archivado,estado.eq.cobrado') 
                  .gte('created_at', _fechaInicio.toIso8601String())
                  .lt('created_at', _fechaFin.add(const Duration(days: 1)).toIso8601String())
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

                final pedidosFiltrados = snapshot.data as List<dynamic>? ?? [];

                int totalDia = 0;
                int totalEfectivo = 0;
                int totalMercadoPago = 0;
                int totalTarjeta = 0;
                
                Map<String, int> conteoProductos = {};

                for (var pedido in pedidosFiltrados) {
                  int monto = (pedido['total'] as num).toInt();
                  totalDia += monto;
                  
                  final metodo = pedido['metodo_pago']?.toString().toLowerCase() ?? '';
                  if (metodo == 'efectivo') totalEfectivo += monto;
                  else if (metodo == 'mercadopago') totalMercadoPago += monto;
                  else if (metodo == 'tarjeta') totalTarjeta += monto;

                  final items = pedido['pedido_items'] as List<dynamic>? ?? [];
                  for (var it in items) {
                    final nombreProd = it['productos']?['nombre'] ?? 'Desconocido';
                    conteoProductos[nombreProd] = (conteoProductos[nombreProd] ?? 0) + 1;
                  }
                }

                int ticketPromedio = pedidosFiltrados.isEmpty ? 0 : totalDia ~/ pedidosFiltrados.length;

                var rankingProductos = conteoProductos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                return ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        border: Border(bottom: BorderSide(color: Colors.indigo.shade200, width: 2))
                      ),
                      child: Column(
                        children: [
                          const Text('RECAUDACIÓN DEL PERIODO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('\$$totalDia', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CajaDetalle(titulo: 'Efectivo', monto: totalEfectivo, color: Colors.green),
                              _CajaDetalle(titulo: 'MercadoPago', monto: totalMercadoPago, color: Colors.blue),
                              _CajaDetalle(titulo: 'Tarjeta', monto: totalTarjeta, color: Colors.orange),
                            ],
                          )
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: _TarjetaMetrica(titulo: 'MESAS ATENDIDAS', valor: '${pedidosFiltrados.length}', icono: Icons.table_restaurant)),
                              const SizedBox(width: 10),
                              Expanded(child: _TarjetaMetrica(titulo: 'TICKET PROMEDIO', valor: '\$$ticketPromedio', icono: Icons.receipt_long)),
                            ],
                          ),
                          const SizedBox(height: 25),
                          
                          const Text('Distribución de Pagos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
                            child: Column(
                              children: [
                                _BarraProgreso(titulo: 'Efectivo', monto: totalEfectivo, total: totalDia, color: Colors.green),
                                const SizedBox(height: 10),
                                _BarraProgreso(titulo: 'MercadoPago', monto: totalMercadoPago, total: totalDia, color: Colors.blue),
                                const SizedBox(height: 10),
                                _BarraProgreso(titulo: 'Tarjeta', monto: totalTarjeta, total: totalDia, color: Colors.orange),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),

                          if (rankingProductos.isNotEmpty) ...[
                            const Text('Top 5 Platos Más Vendidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: rankingProductos.length > 5 ? 5 : rankingProductos.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final prod = rankingProductos[index];
                                  return ListTile(
                                    leading: CircleAvatar(backgroundColor: Colors.indigo.shade100, child: Text('#${index + 1}', style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.bold))),
                                    title: Text(prod.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: Text('${prod.value} uds.', style: const TextStyle(color: Colors.grey)),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 25),
                          ],

                          const Text('Detalle de Tickets Cerrados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),

                    if (pedidosFiltrados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text('Aún no hay ventas cobradas en esta fecha.', style: TextStyle(fontSize: 16, color: Colors.grey))),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true, 
                        physics: const NeverScrollableScrollPhysics(), 
                        itemCount: pedidosFiltrados.length,
                        itemBuilder: (context, index) {
                          final pedido = pedidosFiltrados[index];
                          final hora = DateTime.parse(pedido['created_at']).toLocal();
                          final horaTexto = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade100,
                                child: const Icon(Icons.check, color: Colors.indigo),
                              ),
                              title: Text('Mesa ${pedido['numero_mesa']} - \$${pedido['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Cobrado a las $horaTexto hs'),
                              trailing: Chip(
                                label: Text(pedido['metodo_pago'] ?? 'N/A', style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          );
                        },
                      ),
                      
                    const SizedBox(height: 40), 
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _CajaDetalle extends StatelessWidget {
  final String titulo;
  final int monto;
  final Color color;

  const _CajaDetalle({required this.titulo, required this.monto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text('\$$monto', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
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
          Icon(icono, color: Colors.indigo, size: 24),
          const SizedBox(height: 10),
          Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
        ],
      ),
    );
  }
}

class _BarraProgreso extends StatelessWidget {
  final String titulo;
  final int monto;
  final int total;
  final Color color;

  const _BarraProgreso({required this.titulo, required this.monto, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final porcentaje = total == 0 ? 0.0 : monto / total;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('\$$monto (${(porcentaje * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: porcentaje,
          backgroundColor: Colors.grey.shade200,
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(5),
        ),
      ],
    );
  }
}