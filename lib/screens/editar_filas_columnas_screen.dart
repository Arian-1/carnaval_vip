import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'editar_precios_screen.dart';

class EditarFilasColumnasScreen extends StatefulWidget {
  const EditarFilasColumnasScreen({Key? key}) : super(key: key);

  @override
  State<EditarFilasColumnasScreen> createState() => _EditarFilasColumnasScreenState();
}

class _EditarFilasColumnasScreenState extends State<EditarFilasColumnasScreen> {
  int _tempRowCount = 1;
  int _tempColCount = 1;
  Set<String> _occupiedSeats = {};

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  /// Carga los valores iniciales de Firestore (rowCount, colCount, occupiedSeats).
  Future<void> _cargarDatosIniciales() async {
    final doc = await FirebaseFirestore.instance
        .collection('salas')
        .doc('sala1')
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _tempRowCount = data['rowCount'] ?? 3;
        _tempColCount = data['colCount'] ?? 10;
        List<dynamic> occupiedList = data['occupiedSeats'] ?? [];
        _occupiedSeats = occupiedList.map((e) => e.toString()).toSet();
      });
    }
  }

  /// Convierte 'A5' en (rowIndex=0, colIndex=4). Retorna null si es inválido.
  Map<String, int>? _parseSeatIdSafe(String seatId) {
    if (seatId.length < 2) return null;
    try {
      final letter = seatId[0];
      final seatNumberStr = seatId.substring(1);
      final rowIndex = letter.codeUnitAt(0) - 'A'.codeUnitAt(0);
      final colIndex = int.parse(seatNumberStr) - 1;
      return {'rowIndex': rowIndex, 'colIndex': colIndex};
    } catch (_) {
      return null;
    }
  }

  /// Verifica si podemos decrementar el número de filas.
  bool _canDecrementRows() {
    if (_tempRowCount <= 1) return false;
    final newCount = _tempRowCount - 1;

    for (var seat in _occupiedSeats) {
      final info = _parseSeatIdSafe(seat);
      if (info == null) {
        // Si el seatId es inválido, lo ignoramos.
        continue;
      }
      // Si este asiento está fuera del rango actual, lo ignoramos.
      // (Por ejemplo, rowIndex=10 pero _tempRowCount=3 => es un seat "fantasma")
      if (info['rowIndex']! >= _tempRowCount) {
        continue;
      }
      // Ahora, si el asiento está dentro de la fila que queremos eliminar,
      // no podemos reducir.
      if (info['rowIndex']! >= newCount) {
        return false;
      }
    }
    return true;
  }

  /// Verifica si podemos decrementar el número de columnas.
  bool _canDecrementCols() {
    if (_tempColCount <= 1) return false;
    final newCount = _tempColCount - 1;

    for (var seat in _occupiedSeats) {
      final info = _parseSeatIdSafe(seat);
      if (info == null) {
        continue;
      }
      // Si este asiento está fuera del rango actual de columnas, lo ignoramos.
      if (info['colIndex']! >= _tempColCount) {
        continue;
      }
      // Si el asiento está en la columna que se eliminaría, no podemos reducir.
      if (info['colIndex']! >= newCount) {
        return false;
      }
    }
    return true;
  }

  Future<void> _guardarFilasColumnas() async {
    // Guardar en Firestore los nuevos valores
    await FirebaseFirestore.instance.collection('salas').doc('sala1').update({
      'rowCount': _tempRowCount,
      'colCount': _tempColCount,
    });

    // Navegar a la pantalla de edición de precios
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditarPreciosScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CARNAVAL VIP", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF5A0F4D),
      ),
      body: Center(
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Editar sillas en tarima",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Número de filas:"),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_canDecrementRows()) {
                              setState(() {
                                _tempRowCount--;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text("$_tempRowCount"),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _tempRowCount++;
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Número de columnas:"),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_canDecrementCols()) {
                              setState(() {
                                _tempColCount--;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text("$_tempColCount"),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _tempColCount++;
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _guardarFilasColumnas,
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  label: const Text("Editar", style: TextStyle(color: Colors.white)),
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
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

