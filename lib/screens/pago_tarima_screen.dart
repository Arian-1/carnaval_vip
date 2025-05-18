// lib/screens/pago_tarima_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'asignacion_exitosa_screen.dart';

class PagoTarimaScreen extends StatefulWidget {
  final String tarimaName;  // "Tarima 1", "Tarima 2", …
  final int tarimaPrice;
  final int zona;           // índice 0-based de la zona

  const PagoTarimaScreen({
    Key? key,
    required this.tarimaName,
    required this.tarimaPrice,
    required this.zona,
  }) : super(key: key);

  @override
  State<PagoTarimaScreen> createState() => _PagoTarimaScreenState();
}

class _PagoTarimaScreenState extends State<PagoTarimaScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _abonoCtrl;

  bool _isPendiente = false; // false = pagado, true = pendiente

  @override
  void initState() {
    super.initState();
    // inicializo controles con texto vacío (o podrías pasar valores predeterminados)
    _nombreCtrl   = TextEditingController();
    _apellidoCtrl = TextEditingController();
    _abonoCtrl    = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _abonoCtrl.dispose();
    super.dispose();
  }

  double get _abono {
    if (!_isPendiente) return widget.tarimaPrice.toDouble();
    return double.tryParse(_abonoCtrl.text) ?? 0.0;
  }

  double get _pendiente {
    final restante = widget.tarimaPrice.toDouble() - _abono;
    return restante < 0 ? 0 : restante;
  }

  Future<void> _asignar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final reservaData = {
      'tipo': 'tarima',
      'zona': widget.zona,
      'item': widget.tarimaName,
      'total': widget.tarimaPrice,
      'pagado': !_isPendiente,
      'abono': _abono,
      'pendiente': _pendiente,
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'fecha': FieldValue.serverTimestamp(),
    };

    // Guardar en users/<uid>/reservas
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reservas')
        .add(reservaData);

    // Navegar a confirmación
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AsignacionExitosaScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago de tarima', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text('Pago de ${widget.tarimaName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Nombre del cliente
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del cliente'),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingrese el nombre' : null,
                  ),
                  const SizedBox(height: 12),

                  // Apellido del cliente
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration: const InputDecoration(labelText: 'Apellido del cliente'),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ingrese el apellido' : null,
                  ),
                  const SizedBox(height: 20),

                  // Resumen de tarima y total
                  Text('Tarima: ${widget.tarimaName}'),
                  Text('Total: \$${widget.tarimaPrice}'),
                  const SizedBox(height: 20),

                  // Opción Pagado / Pendiente
                  Row(children: [
                    const Text('Pagado'),
                    Radio<bool>(
                      value: false,
                      groupValue: _isPendiente,
                      onChanged: (v) => setState(() => _isPendiente = false),
                    ),
                    const SizedBox(width: 24),
                    const Text('Pendiente'),
                    Radio<bool>(
                      value: true,
                      groupValue: _isPendiente,
                      onChanged: (v) => setState(() => _isPendiente = true),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Si está pendiente, muestro campo de abono y restante
                  if (_isPendiente) ...[
                    TextFormField(
                      controller: _abonoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Abono'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null) return 'Ingresa un número válido';
                        if (val < 0) return 'No puede ser negativo';
                        if (val > widget.tarimaPrice) return 'No puede exceder el total';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Pendiente: \$${_pendiente.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                  ],

                  // Botón Asignar
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _asignar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D0909),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Asignar', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
