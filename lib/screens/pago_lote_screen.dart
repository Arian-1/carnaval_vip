// lib/screens/pago_lote_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'confirmacion_lote_screen.dart';

class PagoLoteScreen extends StatefulWidget {
  final String loteName;
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
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _abonoCtrl    = TextEditingController(text: '0');

  bool _isPendiente = false;

  int get _abono     => int.tryParse(_abonoCtrl.text) ?? 0;
  int get _total     => widget.lotePrice;
  int get _pendiente => _isPendiente ? (_total - _abono).clamp(0, _total) : 0;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _abonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _asignarLote() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // 1) Preparar datos de reserva
    final reservaData = {
      'tipo': 'lote',                  // para filtrar más tarde
      'zona': widget.loteName.split(' ').last, // ej. "1" de "Lote 1"
      'item': widget.loteName,
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'pagado': !_isPendiente,
      'abono': _isPendiente ? _abono : _total,
      'pendiente': _pendiente,
      'total': _total,
      'fecha': FieldValue.serverTimestamp(),
    };

    // 2) Guardar reserva
    await userRef.collection('reservas').add(reservaData);

    // 3) Ir a confirmación
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConfirmacionLoteScreen()),
    );
  }

  String? _validarNombre(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa nombre';
    return null;
  }

  String? _validarApellido(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa apellido';
    return null;
  }

  String? _validarAbono(String? v) {
    if (!_isPendiente) return null;
    final x = int.tryParse(v ?? '');
    if (x == null) return 'Número inválido';
    if (x < 0 || x > _total) return 'Debe estar entre 0 y $_total';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago de lote', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5E1A47),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Resumen de pago',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Nombre
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _validarNombre,
              ),
              const SizedBox(height: 12),

              // Apellido
              TextFormField(
                controller: _apellidoCtrl,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: _validarApellido,
              ),
              const SizedBox(height: 16),

              // Lote / Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lote:'),
                  Text(widget.loteName),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:'),
                  Text('\$${_total}'),
                ],
              ),
              const SizedBox(height: 20),

              // Pagado / Pendiente
              Row(
                children: [
                  const Text('Pagado'),
                  Radio<bool>(
                    value: false,
                    groupValue: _isPendiente,
                    onChanged: (v) => setState(() => _isPendiente = v!),
                  ),
                  const SizedBox(width: 24),
                  const Text('Pendiente'),
                  Radio<bool>(
                    value: true,
                    groupValue: _isPendiente,
                    onChanged: (v) {
                      setState(() => _isPendiente = v!);
                      if (!_isPendiente) {
                        _abonoCtrl.text = '0';
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Abono
              if (_isPendiente) ...[
                TextFormField(
                  controller: _abonoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Abono'),
                  validator: _validarAbono,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pendiente:'),
                    Text('\$${_pendiente}'),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Botones
              ElevatedButton.icon(
                onPressed: _asignarLote,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Confirmar'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Regresar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
