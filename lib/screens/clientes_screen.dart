import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // para formatear la fecha

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({Key? key}) : super(key: key);

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Lista completa de reservas
  List<Map<String, dynamic>> _allReservas = [];

  /// Lista filtrada (según búsqueda)
  List<Map<String, dynamic>> _filteredReservas = [];

  @override
  void initState() {
    super.initState();
    _fetchReservas();
  }

  /// Lee todos los documentos de la colección "reservas"
  /// y los guarda en _allReservas
  Future<void> _fetchReservas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reservas')
          .orderBy('fecha', descending: true) // opcional: orden por fecha
          .get();

      final List<Map<String, dynamic>> reservasList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // data ya es Map<String,dynamic>
        // Añadimos el id del doc por si lo necesitas
        data['id'] = doc.id;
        reservasList.add(data);
      }

      setState(() {
        _allReservas = reservasList;
        _filteredReservas = reservasList;
      });
    } catch (e) {
      print("Error al leer reservas: $e");
    }
  }

  /// Filtra la lista según el texto ingresado en _searchController
  void _filterReservas(String query) {
    query = query.toLowerCase();
    final filtered = _allReservas.where((res) {
      final nombre = (res['nombre'] ?? '').toString().toLowerCase();
      final apellido = (res['apellido'] ?? '').toString().toLowerCase();
      final fullName = '$nombre $apellido'; // "juan perez"
      return fullName.contains(query);
    }).toList();

    setState(() {
      _filteredReservas = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5E1A47),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barra de búsqueda
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterReservas,
                    decoration: const InputDecoration(
                      hintText: "Buscar",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Encabezado de la tabla (Nombre, Asientos/Lote, Estatus)
            Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    "Nombre",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "Asiento(s)/Lote",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Estatus",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 40), // espacio para el icono info
              ],
            ),
            const Divider(thickness: 1),

            // Lista de reservas
            Expanded(
              child: _filteredReservas.isEmpty
                  ? const Center(child: Text("No hay resultados"))
                  : ListView.builder(
                itemCount: _filteredReservas.length,
                itemBuilder: (context, index) {
                  final reserva = _filteredReservas[index];
                  final nombre = (reserva['nombre'] ?? '').toString();
                  final apellido = (reserva['apellido'] ?? '').toString();
                  final fullName = "$nombre $apellido";
                  final bool pagado = (reserva['pagado'] ?? false) == true;
                  final estatus = pagado ? "Pagado" : "Pendiente";

                  // Dependiendo de si es "tipo": "lote" o "silla"
                  String asientosOLote = "";
                  if (reserva['tipo'] == 'lote') {
                    asientosOLote = reserva['lote'] ?? '';
                  } else if (reserva['tipo'] == 'silla') {
                    // Podría ser una lista de asientos
                    final asientos = reserva['asientos'];
                    if (asientos is List) {
                      asientosOLote = asientos.join(", ");
                    }
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(fullName),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(asientosOLote),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(estatus),
                          ),
                          IconButton(
                            icon: const Icon(Icons.info),
                            onPressed: () {
                              _showReservaDetails(reserva);
                            },
                          ),
                        ],
                      ),
                      const Divider(thickness: 1),
                    ],
                  );
                },
              ),
            ),

            // Botón para "Descargar tabla de clientes"
            ElevatedButton.icon(
              onPressed: () {
                // Aquí puedes implementar la lógica para generar un PDF/CSV
                // y descargarlo.
              },
              icon: const Icon(Icons.download),
              label: const Text("Descargar tabla de clientes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra un modal (dialog) con los detalles de la reserva
  void _showReservaDetails(Map<String, dynamic> reserva) {
    final nombre = reserva['nombre'] ?? '';
    final apellido = reserva['apellido'] ?? '';
    final abono = reserva['abono'] ?? 0;
    final pendiente = reserva['pendiente'] ?? 0;
    final total = reserva['total'] ?? 0;
    final fecha = reserva['fecha'];
    final tipo = reserva['tipo'] ?? '';
    final pagado = (reserva['pagado'] ?? false) == true;

    // formatear fecha si es Timestamp
    String fechaStr = '';
    if (fecha != null && fecha is Timestamp) {
      fechaStr = DateFormat('dd/MM/yyyy, hh:mm a').format(fecha.toDate());
    }

    // Asientos o lote
    String detallesAsientos = '';
    if (tipo == 'lote') {
      detallesAsientos = "Lote: ${reserva['lote']}";
    } else if (tipo == 'silla') {
      final asientos = reserva['asientos'];
      if (asientos is List) {
        detallesAsientos = "Asientos: ${asientos.join(", ")}";
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Detalles de la reserva"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nombre: $nombre $apellido"),
            Text("Tipo: $tipo"),
            if (detallesAsientos.isNotEmpty) Text(detallesAsientos),
            if (reserva.containsKey('lote')) Text("Lote: ${reserva['lote']}"),
            const SizedBox(height: 8),
            Text("Pagado: ${pagado ? 'Sí' : 'No'}"),
            Text("Abono: \$$abono"),
            Text("Pendiente: \$$pendiente"),
            Text("Total: \$$total"),
            Text("Fecha: $fechaStr"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
