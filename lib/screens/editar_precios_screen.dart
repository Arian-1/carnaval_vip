import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'confirmacion_edicion_screen.dart';

class EditarPreciosScreen extends StatefulWidget {
  const EditarPreciosScreen({Key? key}) : super(key: key);

  @override
  State<EditarPreciosScreen> createState() => _EditarPreciosScreenState();
}

class _EditarPreciosScreenState extends State<EditarPreciosScreen> {
  /// Controladores para los campos de texto
  final List<TextEditingController> _controllers = [];

  /// Cantidad de filas actual en la base
  int _rowCount = 0;

  /// Lectura inicial desde Firestore.
  /// - Se llama 1 sola vez en [initState].
  Future<Map<int, int>> _fetchRowPrices() async {
    final doc = await FirebaseFirestore.instance
        .collection('salas')
        .doc('sala1')
        .get();

    if (!doc.exists) {
      return {}; // si no existe el doc, devolvemos vacío
    }

    final data = doc.data() as Map<String, dynamic>;
    _rowCount = data['rowCount'] ?? 3;

    final rawPrices = data['rowPrices'] ?? {};
    // rawPrices debería ser algo como: {"0":250, "1":200, "2":150}
    // Convertimos a Map<int,int>
    final rowPrices = <int, int>{};
    rawPrices.forEach((key, value) {
      final intKey = int.tryParse(key) ?? 0;
      rowPrices[intKey] = (value is int) ? value : 0;
    });

    return rowPrices;
  }

  /// Actualiza Firestore con los precios editados
  Future<void> _guardarPrecios() async {
    // Preparamos un Map<String,int> para subir a Firestore
    final Map<String, int> pricesToSave = {};
    for (int i = 0; i < _rowCount; i++) {
      final precio = int.tryParse(_controllers[i].text) ?? 0;
      pricesToSave[i.toString()] = precio;
    }

    await FirebaseFirestore.instance.collection('salas').doc('sala1').update({
      'rowPrices': pricesToSave,
    });

    // Navegar a pantalla de confirmación
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfirmacionEdicionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar precios por fila", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
      ),
      body: FutureBuilder<Map<int, int>>(
        future: _fetchRowPrices(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // Esperando a que lleguen los datos
            return const Center(child: CircularProgressIndicator());
          }

          // rowPrices que vienen de Firestore
          final rowPrices = snapshot.data!; // Map<int,int>
          // Actualizamos la lista de controladores
          _controllers.clear();
          for (int i = 0; i < _rowCount; i++) {
            final precio = rowPrices[i] ?? 0;
            _controllers.add(TextEditingController(text: precio.toString()));
          }

          // Construimos la UI con la info ya cargada
          return Center(
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(16.0),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text("Editar precios por fila",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Para que la lista sea visible, necesitamos un contenedor con altura
                    // o un Expanded si estamos dentro de una columna con altura limitada.
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: _rowCount,
                        itemBuilder: (context, index) {
                          final letra = String.fromCharCode(65 + index); // A, B, C...
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Fila $letra:", style: const TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: _controllers[index],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _guardarPrecios,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text("Guardar", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text("Regresar"),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}



