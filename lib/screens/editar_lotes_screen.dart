import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'editar_lote_precio_screen.dart';

class EditarLotesScreen extends StatefulWidget {
  const EditarLotesScreen({Key? key}) : super(key: key);

  @override
  State<EditarLotesScreen> createState() => _EditarLotesScreenState();
}

class _EditarLotesScreenState extends State<EditarLotesScreen> {
  int _tempLoteCount = 3;
  // Usamos un Set de índices (0-indexed) para los lotes ocupados.
  Set<int> _occupiedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final doc =
    await FirebaseFirestore.instance.collection('salas').doc('sala1').get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _tempLoteCount = data['loteCount'] ?? 3;
        List<dynamic> occupied = data['occupiedLotes'] ?? [];
        _occupiedIndices.clear();
        for (var lote in occupied) {
          if (lote is String) {
            String numberStr = lote.replaceAll("Lote ", "");
            int lotNum = int.tryParse(numberStr) ?? 0;
            if (lotNum > 0) {
              _occupiedIndices.add(lotNum - 1);
            }
          }
        }
      });
    }
  }

  bool _canDecrementLotes() {
    if (_tempLoteCount <= 1) return false;
    final newCount = _tempLoteCount - 1;
    // Si hay algún lote ocupado cuyo índice sea >= newCount, no se puede reducir.
    for (var index in _occupiedIndices) {
      if (index >= newCount) return false;
    }
    return true;
  }

  Future<void> _saveLoteCount() async {
    await FirebaseFirestore.instance
        .collection('salas')
        .doc('sala1')
        .update({'loteCount': _tempLoteCount});
    // Navega a la pantalla de edición de precio
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditarLotePrecioScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar lotes", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF5E1A47),
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
                const Text("Editar cantidad de lotes",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Número de lotes:"),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_canDecrementLotes()) {
                              setState(() {
                                _tempLoteCount--;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text("$_tempLoteCount"),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _tempLoteCount++;
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
                  onPressed: _saveLoteCount,
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  label: const Text("Editar", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
