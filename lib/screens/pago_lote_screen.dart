import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'confirmacion_lote_screen.dart';

class PagoLoteScreen extends StatefulWidget {
  final List<String> loteNames;
  final int lotePrice;
  final int zona;

  const PagoLoteScreen({
    Key? key,
    required this.loteNames,
    required this.lotePrice,
    required this.zona,
  }) : super(key: key);

  @override
  State<PagoLoteScreen> createState() => _PagoLoteScreenState();
}

class _PagoLoteScreenState extends State<PagoLoteScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _abonoCtrl    = TextEditingController(text: '0');

  bool _isPendiente = false;

  double get _totalPrice => widget.loteNames.length * widget.lotePrice.toDouble();
  double get _abono      => !_isPendiente
      ? _totalPrice
      : double.tryParse(_abonoCtrl.text) ?? 0.0;
  double get _pendiente  => (_totalPrice - _abono).clamp(0.0, _totalPrice);

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _abonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _asignarLotes() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid   = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();
    final col   = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('reservas');

    // abono proporcional por lote si está pendiente
    final abonoPorLote = !_isPendiente
        ? widget.lotePrice.toDouble()
        : (_abono / widget.loteNames.length);

    for (var name in widget.loteNames) {
      final doc    = col.doc();
      final pago   = !_isPendiente;
      final abono  = abonoPorLote;
      final pend   = widget.lotePrice.toDouble() - abono;
      batch.set(doc, {
        'tipo':      'lote',
        'zona':      widget.zona+1,
        'item':      name,
        'total':     widget.lotePrice,
        'pagado':    pago,
        'abono':     abono,
        'pendiente': pend < 0 ? 0 : pend,
        'nombre':    _nombreCtrl.text.trim(),
        'apellido':  _apellidoCtrl.text.trim(),
        'fecha':     FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ConfirmacionLoteScreen()),
    );
  }

  String? _validaTexto(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  String? _validaAbono(String? v) {
    if (!_isPendiente) return null;
    final x = double.tryParse(v ?? '');
    if (x == null) return 'Número inválido';
    if (x < 0 || x > _totalPrice) return 'Debe estar entre 0 y $_totalPrice';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago de lotes', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Lotes seleccionados: ${widget.loteNames.join(', ')}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total a pagar: \$${_totalPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del cliente'),
              validator: _validaTexto,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apellidoCtrl,
              decoration: const InputDecoration(labelText: 'Apellido del cliente'),
              validator: _validaTexto,
            ),
            const SizedBox(height: 20),

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

            if (_isPendiente) ...[
              TextFormField(
                controller: _abonoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Abono total'),
                validator: _validaAbono,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text('Restante: \$${_pendiente.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
            ],

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _asignarLotes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D0909),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
