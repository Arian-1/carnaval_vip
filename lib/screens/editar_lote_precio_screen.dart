import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'confirmacion_edicion_screen.dart';

class EditarLotePrecioScreen extends StatefulWidget {
  const EditarLotePrecioScreen({Key? key}) : super(key: key);

  @override
  State<EditarLotePrecioScreen> createState() => _EditarLotePrecioScreenState();
}

class _EditarLotePrecioScreenState extends State<EditarLotePrecioScreen> {
  final TextEditingController _controller = TextEditingController();

  Future<int> _fetchLotePrice() async {
    final doc = await FirebaseFirestore.instance
        .collection('salas')
        .doc('sala1')
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['lotePrice'] ?? 500;
    }
    return 500;
  }

  Future<void> _saveLotePrice() async {
    int newPrice = int.tryParse(_controller.text) ?? 500;
    await FirebaseFirestore.instance
        .collection('salas')
        .doc('sala1')
        .update({'lotePrice': newPrice});
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfirmacionEdicionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Editar precio de lote", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5E1A47),
      ),
      body: FutureBuilder<int>(
        future: _fetchLotePrice(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          _controller.text = snapshot.data.toString();
          return Center(
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(16.0),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Editar precio de lote",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Precio",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saveLotePrice,
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
