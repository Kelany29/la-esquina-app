import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 
import 'package:qr_flutter/qr_flutter.dart'; 

// ✨ NUEVO: El "Cerebro" de la Caja. Mantiene los datos vivos aunque cambies de pantalla.
class EstadoCaja {
  static bool abierta = false;
  static int fondoEfectivo = 0;
  static int fondoMP = 0;

  static void cerrarCaja() {
    abierta = false;
    fondoEfectivo = 0;
    fondoMP = 0;
  }
}

class PantallaCaja extends StatefulWidget {
  const PantallaCaja({super.key});

  @override
  State<PantallaCaja> createState() => _PantallaCajaState();
}

class _PantallaCajaState extends State<PantallaCaja> {
  // Para el Turno Actual (Día de hoy)
  late Stream<List<Map<String, dynamic>>> _streamCajaHoy;
  
  // Para el Historial
  DateTime _fechaVisualizada = DateTime.now();

  @override
  void initState() {
    super.initState();
    _configurarStreamHoy();
  }

  void _configurarStreamHoy() {
    _streamCajaHoy = Supabase.instance.client
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('estado', 'cobrado')
        .order('created_at');
  }

  void _cambiarDiaHistorial(int dias) {
    setState(() {
      _fechaVisualizada = _fechaVisualizada.add(Duration(days: dias));
    });
  }

  void _dialogoAperturaCaja() {
    final efectivoController = TextEditingController(text: EstadoCaja.fondoEfectivo == 0 ? '' : EstadoCaja.fondoEfectivo.toString());
    final mpController = TextEditingController(text: EstadoCaja.fondoMP == 0 ? '' : EstadoCaja.fondoMP.toString());

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Text('🔓 Apertura de Caja', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Con cuánto dinero arranca el turno hoy?'),
            const SizedBox(height: 15),
            TextField(
              controller: efectivoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fondo Inicial en Efectivo (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.money, color: Colors.green)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: mpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Saldo Inicial MercadoPago (\$)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code_scanner, color: Colors.blue)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                // ✨ Guardamos los datos en la memoria global
                EstadoCaja.fondoEfectivo = int.tryParse(efectivoController.text) ?? 0;
                EstadoCaja.fondoMP = int.tryParse(mpController.text) ?? 0;
                EstadoCaja.abierta = true; 
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Caja abierta correctamente. ¡Buen turno!'), backgroundColor: Colors.green));
            },
            child: const Text('INICIAR TURNO', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Future<void> _mostrarQRMercadoPago() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blue)));

    String aliasActual = "alias.no.configurado";
    try {
      final res = await Supabase.instance.client.from('configuracion').select('valor').eq('clave', 'alias_mp').maybeSingle();
      if (res != null) aliasActual = res['valor'];
    } catch(e) {
      print("No se encontró la tabla configuracion");
    }

    if (!mounted) return;
    Navigator.pop(context); 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📲 Cobro QR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Cambiar Alias',
                  onPressed: () {
                    final aliasController = TextEditingController(text: aliasActual);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Modificar Alias o Link'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚠️ IMPORTANTE: Para que lo lean las apps bancarias, pegá acá el LINK DE PAGO de Mercado Pago (empieza con http), NO el alias.', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: aliasController,
                              decoration: const InputDecoration(labelText: 'Link o Alias', border: OutlineInputBorder()),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            onPressed: () async {
                              final nuevoAlias = aliasController.text.trim();
                              if (nuevoAlias.isEmpty) return;
                              
                              final existe = await Supabase.instance.client.from('configuracion').select().eq('clave', 'alias_mp').maybeSingle();
                              if (existe != null) {
                                await Supabase.instance.client.from('configuracion').update({'valor': nuevoAlias}).eq('clave', 'alias_mp');
                              } else {
                                await Supabase.instance.client.from('configuracion').insert({'clave': 'alias_mp', 'valor': nuevoAlias});
                              }

                              setStateDialog(() => aliasActual = nuevoAlias);
                              if (!context.mounted) return;
                              Navigator.pop(context); 
                            }, 
                            child: const Text('GUARDAR')
                          )
                        ],
                      )
                    );
                  },
                )
              ],
            ),
            content: SingleChildScrollView( 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 250, 
                    height: 250,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade200, width: 2)),
                    child: QrImageView(
                      data: aliasActual,
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('Alias/Link actual:', style: TextStyle(color: Colors.grey)),
                  Text(aliasActual, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR VENTANA'),
              )
            ],
          );
        }
      ),
    );
  }

  void _dialogoCierreTurno(int cajaTotal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Cierre de Turno', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Estás por cerrar la caja con un total final de \$$cajaTotal (incluyendo el fondo inicial).\n\nEsto archivará las ventas de hoy en el Historial y dejará la caja en \$0 para el próximo turno. ¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); 
              
              try {
                final hoyInicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
                final pedidosDeHoy = await Supabase.instance.client.from('pedidos').select('id').eq('estado', 'cobrado').gte('created_at', hoyInicio);
                
                for (var pedido in pedidosDeHoy) {
                  await Supabase.instance.client.from('pedidos').update({'estado': 'archivado'}).eq('id', pedido['id']);
                }

                if (!mounted) return;
                
                setState(() {
                  // ✨ Limpiamos la memoria global
                  EstadoCaja.cerrarCaja(); 
                });

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Turno cerrado con éxito. Las ventas pasaron al historial.'), backgroundColor: Colors.green));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al cerrar: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('SÍ, CERRAR TURNO'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('💰 CAJA Y FINANZAS', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            tabs: [
              Tab(icon: Icon(Icons.point_of_sale), text: 'TURNO ACTUAL'),
              Tab(icon: Icon(Icons.date_range), text: 'HISTORIAL'),
            ],
          ),
        ),
        backgroundColor: Colors.grey.shade100,
        body: SafeArea(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(), 
            children: [
              // ------------------------------------
              // PESTAÑA 1: TURNO ACTUAL
              // ------------------------------------
              !EstadoCaja.abierta 
              ? _construirPantallaCajaCerrada() 
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _streamCajaHoy, 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

                    final todasLasVentas = snapshot.data ?? [];
                    
                    final hoyInicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    final ventas = todasLasVentas.where((venta) {
                      final fechaVenta = DateTime.parse(venta['created_at']).toLocal();
                      return fechaVenta.isAfter(hoyInicio) || fechaVenta.isAtSameMomentAs(hoyInicio);
                    }).toList();

                    int ventasEfectivo = 0, ventasMP = 0, ventasTarjeta = 0, granTotalVentas = 0;

                    for (var venta in ventas) {
                      final monto = (venta['total'] as num).toInt();
                      granTotalVentas += monto;
                      final metodo = venta['metodo_pago']?.toString().toLowerCase() ?? '';
                      if (metodo == 'efectivo') ventasEfectivo += monto;
                      else if (metodo == 'mercadopago') ventasMP += monto;
                      else if (metodo == 'tarjeta') ventasTarjeta += monto;
                    }

                    // ✨ Usamos los fondos de la memoria global
                    int cajaRealEfectivo = ventasEfectivo + EstadoCaja.fondoEfectivo;
                    int cajaRealMP = ventasMP + EstadoCaja.fondoMP;
                    int cajaRealTotal = granTotalVentas + EstadoCaja.fondoEfectivo + EstadoCaja.fondoMP;

                    return Column(
                      children: [
                        _construirPanelResumen(
                          total: cajaRealTotal, 
                          efectivo: cajaRealEfectivo, 
                          mp: cajaRealMP, 
                          tarjeta: ventasTarjeta, 
                          titulo: 'CAJA TOTAL (Ventas + Fondo)',
                          esTurnoActual: true 
                        ),
                        const SizedBox(height: 10),
                        Expanded(child: _construirListaVentas(ventas, vacioMensaje: 'Aún no hay ventas cobradas hoy.')),
                        Container(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 30),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                            ),
                            onPressed: () => _dialogoCierreTurno(cajaRealTotal),
                            icon: const Icon(Icons.lock_clock), label: const Text('CERRAR TURNO (Z)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    );
                  },
                ),

              // ------------------------------------
              // PESTAÑA 2: HISTORIAL
              // ------------------------------------
              Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          color: Colors.green.shade800,
                          onPressed: () => _cambiarDiaHistorial(-1),
                        ),
                        Column(
                          children: [
                            const Text('Mostrando ventas del:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_fechaVisualizada),
                              style: TextStyle(fontSize: 20, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          color: Colors.green.shade800,
                          onPressed: () => _cambiarDiaHistorial(1),
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: RefreshIndicator(
                      color: Colors.green.shade800,
                      backgroundColor: Colors.white,
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: FutureBuilder(
                        future: Supabase.instance.client
                            .from('pedidos')
                            .select()
                            .eq('estado', 'archivado')
                            .gte('created_at', DateTime(_fechaVisualizada.year, _fechaVisualizada.month, _fechaVisualizada.day).toIso8601String())
                            .lt('created_at', DateTime(_fechaVisualizada.year, _fechaVisualizada.month, _fechaVisualizada.day).add(const Duration(days: 1)).toIso8601String()) 
                            .order('created_at', ascending: false),
                        builder: (context, snapshotHistorico) {
                          if (snapshotHistorico.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          if (snapshotHistorico.hasError) return Center(child: Text('Error: ${snapshotHistorico.error}'));

                          final ventasHistoricas = snapshotHistorico.data as List<dynamic>? ?? [];
                          
                          int totalEfectivo = 0, totalMP = 0, totalTarjeta = 0, granTotal = 0;
                          for (var venta in ventasHistoricas) {
                            final monto = (venta['total'] as num).toInt();
                            granTotal += monto;
                            final metodo = venta['metodo_pago']?.toString().toLowerCase() ?? '';
                            if (metodo == 'efectivo') totalEfectivo += monto;
                            else if (metodo == 'mercadopago') totalMP += monto;
                            else if (metodo == 'tarjeta') totalTarjeta += monto;
                          }

                          return Column(
                            children: [
                              _construirPanelResumen(
                                total: granTotal, 
                                efectivo: totalEfectivo, 
                                mp: totalMP, 
                                tarjeta: totalTarjeta, 
                                titulo: 'TOTAL FACTURADO',
                                esTurnoActual: false
                              ),
                              const SizedBox(height: 10),
                              Expanded(child: _construirListaVentas(ventasHistoricas, vacioMensaje: 'No hay registros en este día.')),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirPantallaCajaCerrada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 80, color: Colors.green.shade200),
            const SizedBox(height: 20),
            const Text('¡Comencemos a trabajar!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            const Text('La caja se encuentra cerrada. Ingresá el dinero de cambio inicial para comenzar a registrar las ventas de hoy.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
              ),
              onPressed: _dialogoAperturaCaja, 
              icon: const Icon(Icons.lock_open, size: 28), 
              label: const Text('ABRIR CAJA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            )
          ],
        ),
      ),
    );
  }

  Widget _construirPanelResumen({required int total, required int efectivo, required int mp, required int tarjeta, required String titulo, required bool esTurnoActual}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))
      ),
      child: Column(
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('\$$total', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
          
          if (esTurnoActual) ...[
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    onPressed: _mostrarQRMercadoPago, 
                    icon: const Icon(Icons.qr_code), 
                    label: const Text('Cobrar QR')
                  ),
                )
              ],
            )
          ],

          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _CajaDetalle(titulo: 'Efectivo', monto: efectivo, color: Colors.green, icono: Icons.money),
              _CajaDetalle(titulo: 'MercadoPago', monto: mp, color: Colors.blue, icono: Icons.qr_code_scanner),
              _CajaDetalle(titulo: 'Tarjeta', monto: tarjeta, color: Colors.orange, icono: Icons.credit_card),
            ],
          )
        ],
      ),
    );
  }

  Widget _construirListaVentas(List<dynamic> ventas, {required String vacioMensaje}) {
    if (ventas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 100, child: Center(child: Text(vacioMensaje, style: const TextStyle(fontSize: 18, color: Colors.grey)))),
        ],
      );
    }
    
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(), 
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: ventas.length,
      itemBuilder: (context, index) {
        final venta = ventas[index]; 
        
        Color iconoColor = Colors.grey;
        IconData iconoPago = Icons.attach_money;
        final metodo = venta['metodo_pago']?.toString().toLowerCase() ?? '';
        if (metodo == 'efectivo') { iconoColor = Colors.green; iconoPago = Icons.money; }
        else if (metodo == 'mercadopago') { iconoColor = Colors.blue; iconoPago = Icons.qr_code_scanner; }
        else if (metodo == 'tarjeta') { iconoColor = Colors.orange; iconoPago = Icons.credit_card; }

        final fechaFormateada = DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.parse(venta['created_at']));

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: iconoColor.withOpacity(0.2), child: Icon(iconoPago, color: iconoColor)),
            title: Text('Mesa ${venta['numero_mesa']} - Ticket #${venta['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Pago: ${venta['metodo_pago']}\n$fechaFormateada', style: const TextStyle(height: 1.3)),
            trailing: Text('\$${venta['total']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _CajaDetalle extends StatelessWidget {
  final String titulo;
  final int monto;
  final Color color;
  final IconData icono;

  const _CajaDetalle({required this.titulo, required this.monto, required this.color, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: color, size: 28),
        const SizedBox(height: 5),
        Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text('\$$monto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}