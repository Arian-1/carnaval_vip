import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'confirmacion_lote_screen.dart';

class PagoLoteScreen extends StatefulWidget {
  final String loteName; // "Lote 1", "Lote 2", ...
  final int lotePrice;

  const PagoLoteScreen({
    Key? key,
    required this.loteName,
    required this.lotePrice,
  }) : super(key: key);

  @override
  State<PagoLoteScreen> createState() => _PagoLoteScreenState();
}

class _PagoLoteScreenState extends State<PagoLoteScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _abonoCtrl = TextEditingController(text: "0");

  bool _isPagado = false;

  int get _abono => int.tryParse(_abonoCtrl.text) ?? 0;
  int get _total => widget.lotePrice;
  int get _pendiente => _total - _abono;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Pago de lote", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5E1A47),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Resumen",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Nombre del cliente
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: "Nombre del cliente",
                  ),
                ),
                const SizedBox(height: 10),
                // Apellido del cliente
                TextFormField(
                  controller: _apellidoCtrl,
                  decoration: const InputDecoration(
                    labelText: "Apellido del cliente",
                  ),
                ),
                const SizedBox(height: 20),
                // Info del lote y total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Lote:"),
                    Text(widget.loteName),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total:"),
                    Text("\$$_total"),
                  ],
                ),
                const SizedBox(height: 10),
                // Radio buttons: Pagado / Pendiente
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: _isPagado,
                      onChanged: (val) {
                        setState(() {
                          _isPagado = val ?? false;
                          _abonoCtrl.text = _total.toString();
                        });
                      },
                    ),
                    const Text("Pagado"),
                    const SizedBox(width: 20),
                    Radio<bool>(
                      value: false,
                      groupValue: _isPagado,
                      onChanged: (val) {
                        setState(() {
                          _isPagado = val ?? false;
                          // Si se cambia a pendiente, no asignar el total automáticamente
                          if (_abonoCtrl.text == _total.toString()) {
                            _abonoCtrl.text = "0";
                          }
                        });
                      },
                    ),
                    const Text("Pendiente"),
                  ],
                ),
                // Abono y pendiente
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Abono:"),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        enabled: !_isPagado, // si es pagado, abono = total
                        controller: _abonoCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (val) => setState(() {}), // para recalcular
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Pendiente:"),
                    Text("\$$_pendiente"),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _asignarLote,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label:
                  const Text("Asignar", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      ),
    );
  }

  /// Función para asignar el lote y guardar la reserva en la colección "reservas"
  Future<void> _asignarLote() async {
    final nombre = _nombreCtrl.text.trim();
    final apellido = _apellidoCtrl.text.trim();

    if (nombre.isEmpty || apellido.isEmpty) {
      _showSnack("Ingresa nombre y apellido.");
      return;
    }
    if (_abono < 0 || _abono > _total) {
      _showSnack("El abono no puede ser mayor que el total ni negativo.");
      return;
    }

    // 1) Actualizar "occupiedLotes" en el documento de la sala para marcar el lote como ocupado.
    final salaRef =
    FirebaseFirestore.instance.collection("salas").doc("sala1");
    final salaSnap = await salaRef.get();
    if (!salaSnap.exists) {
      _showSnack("No se encontró 'sala1' en la base de datos.");
      return;
    }
    final salaData = salaSnap.data() as Map<String, dynamic>;
    List<dynamic> occupiedLotes = salaData["occupiedLotes"] ?? [];
    if (!occupiedLotes.contains(widget.loteName)) {
      occupiedLotes.add(widget.loteName);
      await salaRef.update({"occupiedLotes": occupiedLotes});
    }

    // 2) Crear el registro de la reserva para el lote.
    final reserva = {
      "lote": widget.loteName,
      "nombre": nombre,
      "apellido": apellido,
      "pagado": _isPagado,
      "abono": _abono,
      "pendiente": _pendiente,
      "total": _total,
      "fecha": FieldValue.serverTimestamp(),
      "tipo": "lote" // para identificar el tipo de reserva
    };

    // Enviar la reserva a la colección "reservas"
    await FirebaseFirestore.instance.collection("reservas").add(reserva);

    // 3) Navegar a la pantalla de confirmación
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConfirmacionLoteScreen()),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

