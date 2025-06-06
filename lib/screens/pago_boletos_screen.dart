// lib/screens/pago_boletos_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'asignacion_exitosa_screen.dart';

class PagoBoletosScreen extends StatefulWidget {
  final String nombreCliente;
  final String apellidoCliente;
  final List<String> asientosSeleccionados;
  final int total;
  final int zona; // ← nueva

  const PagoBoletosScreen({
    Key? key,
    required this.nombreCliente,
    required this.apellidoCliente,
    required this.asientosSeleccionados,
    required this.total,
    required this.zona,  // ← obligatorio
  }) : super(key: key);

  @override
  State<PagoBoletosScreen> createState() => _PagoBoletosScreenState();
}

class _PagoBoletosScreenState extends State<PagoBoletosScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _abonoCtrl;

  bool _isPendiente = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl   = TextEditingController(text: widget.nombreCliente);
    _apellidoCtrl = TextEditingController(text: widget.apellidoCliente);
    _abonoCtrl    = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _abonoCtrl.dispose();
    super.dispose();
  }

  double get _abono =>
      _isPendiente ? double.tryParse(_abonoCtrl.text) ?? 0.0 : widget.total.toDouble();

  double get _pendiente {
    final restante = widget.total.toDouble() - _abono;
    return restante < 0 ? 0 : restante;
  }

  Future<void> _asignar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final reservaData = {
      'tipo': 'silla',
      'zona': widget.zona,  // ← aquí
      'asientos': widget.asientosSeleccionados,
      'total': widget.total,
      'pagado': !_isPendiente,
      'abono': _abono,
      'pendiente': _pendiente,
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'fecha': FieldValue.serverTimestamp(),
    };

    // Guardamos en users/<uid>/reservas
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reservas')
        .add(reservaData);

    // Navegamos a la pantalla de confirmación
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
        title: const Text('Pago de boletos', style: TextStyle(color: Colors.white)),
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
                  const Text('Pago de boletos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Nombre
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del cliente'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingrese el nombre' : null,
                  ),
                  const SizedBox(height: 12),

                  // Apellido
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration: const InputDecoration(labelText: 'Apellido del cliente'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingrese el apellido' : null,
                  ),
                  const SizedBox(height: 20),

                  // Resumen
                  Text('Asientos: ${widget.asientosSeleccionados.join(', ')}'),
                  Text('Total: \$${widget.total}'),
                  const SizedBox(height: 20),

                  // Pagado / Pendiente
                  Row(
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Abono si está pendiente
                  if (_isPendiente) ...[
                    TextFormField(
                      controller: _abonoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Abono'),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (_isPendiente) {
                          final val = double.tryParse(v ?? '');
                          if (val == null) return 'Ingresa un número válido';
                          if (val < 0)    return 'No puede ser negativo';
                          if (val > widget.total) return 'No puede exceder el total';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Restante: \$${_pendiente.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                  ],

                  // Botón Asignar
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _asignar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D0909),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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



