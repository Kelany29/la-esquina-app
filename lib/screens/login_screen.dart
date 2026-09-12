import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✨ NUEVO: Necesario para leer el teclado físico
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; 
import '../services/local_db_service.dart'; 
import 'mesas_screen.dart';
import 'cocina_screen.dart';

// "Cerebro" global para recordar quién tiene la tablet
class SesionGlobal {
  static int? idUsuarioActual;
  static String? nombreUsuarioActual;
  static String? rolUsuarioActual;

  static void iniciarSesion(int id, String nombre, String rol) {
    idUsuarioActual = id;
    nombreUsuarioActual = nombre;
    rolUsuarioActual = rol;
  }

  static void cerrarSesion() {
    idUsuarioActual = null;
    nombreUsuarioActual = null;
    rolUsuarioActual = null;
  }
}

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  String _pin = '';
  bool _cargando = false;

  void _presionarNumero(String numero) {
    if (_pin.length < 4) {
      setState(() {
        _pin += numero;
      });
      if (_pin.length == 4) {
        _verificarAcceso();
      }
    }
  }

  void _borrarNumero() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _verificarAcceso() async {
    setState(() => _cargando = true);

    try {
      final conectividad = await Connectivity().checkConnectivity();
      bool sinInternet = false;
      if (conectividad is List) {
        sinInternet = (conectividad as List).contains(ConnectivityResult.none) || (conectividad as List).isEmpty;
      } else {
        sinInternet = conectividad == ConnectivityResult.none;
      }

      Map<String, dynamic>? respuesta;

      if (sinInternet) {
        respuesta = await LocalDbService().verificarPinOffline(_pin);
        
        if (respuesta != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚡ Inicio de sesión Offline'), backgroundColor: Colors.amber),
          );
        }
      } else {
        respuesta = await Supabase.instance.client
            .from('usuarios')
            .select()
            .eq('pin', _pin)
            .maybeSingle();

        if (respuesta != null) {
          final todosLosUsuarios = await Supabase.instance.client.from('usuarios').select();
          await LocalDbService().guardarUsuariosOffline(todosLosUsuarios);
        }
      }

      if (respuesta == null) {
        _mostrarError(sinInternet ? '❌ PIN Incorrecto (Modo Offline)' : '❌ PIN Incorrecto');
      } else {
        if (respuesta['activo'] == false) {
          _mostrarError('🚫 Usuario inactivo. Consulte al administrador.');
          return;
        }

        final id = respuesta['id'];
        final nombre = respuesta['nombre'];
        final rol = respuesta['rol'].toString().toLowerCase();

        SesionGlobal.iniciarSesion(id, nombre, rol);

        if (!mounted) return;
        
        if (!sinInternet) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('👋 ¡Hola, $nombre!'), backgroundColor: Colors.green),
          );
        }

        if (rol == 'cocina') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaCocina()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PantallaMesas(rolUsuario: rol)));
        }
      }
    } catch (e) {
      _mostrarError('❌ Error de sistema: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    setState(() => _pin = ''); 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      // ✨ MAGIA: Envolvemos todo en un Focus para leer teclados físicos (USB, Bluetooth o Smart TV)
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Detectamos solo cuando la tecla se "presiona" hacia abajo
          if (event is KeyDownEvent) {
            // Si apretan la tecla de borrar (Backspace)
            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              _borrarNumero();
              return KeyEventResult.handled;
            }
            
            // Si apretan un número (0 al 9)
            final caracter = event.character;
            if (caracter != null && RegExp(r'^[0-9]$').hasMatch(caracter)) {
              _presionarNumero(caracter);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored; // Ignoramos letras y otras teclas
        },
        child: Center(
          child: SingleChildScrollView( 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 120, 
                  child: Image.asset(
                    'assets/logo.jpeg',
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.storefront, size: 100, color: Colors.deepOrange); 
                    },
                  ),
                ),
                const SizedBox(height: 30),
                
                const Text('INGRESE SU PIN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 30),
                
                // Los 4 puntitos del PIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _pin.length ? Colors.deepOrange : Colors.grey.shade800,
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 50),
                
                // Teclado numérico táctil
                if (_cargando)
                  const CircularProgressIndicator(color: Colors.deepOrange)
                else
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        _filaBotones(['1', '2', '3']),
                        const SizedBox(height: 15),
                        _filaBotones(['4', '5', '6']),
                        const SizedBox(height: 15),
                        _filaBotones(['7', '8', '9']),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(width: 70), // Espacio vacío
                            _botonNumero('0'),
                            _botonAccion(Icons.backspace, _borrarNumero), // Botón borrar
                          ],
                        ),
                      ],
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filaBotones(List<String> numeros) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numeros.map((num) => _botonNumero(num)).toList(),
    );
  }

  Widget _botonNumero(String numero) {
    return InkWell(
      onTap: () => _presionarNumero(numero),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade900),
        alignment: Alignment.center,
        child: Text(numero, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _botonAccion(IconData icono, VoidCallback accion) {
    return InkWell(
      onTap: accion,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade900),
        alignment: Alignment.center,
        child: Icon(icono, size: 32, color: Colors.white),
      ),
    );
  }
}