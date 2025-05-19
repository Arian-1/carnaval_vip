import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'asignacion_exitosa_screen.dart';

class PagoTarimaScreen extends StatefulWidget {
  final List<String> tarimaNames;  // ahora acepta múltiples
  final int tarimaPrice;
  final int zona;                  // índice 0-based

  const PagoTarimaScreen({
    Key? key,
    required this.tarimaNames,
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

  bool _isPendiente = false;

  @override
  void initState() {
    super.initState();
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

  double get _totalPrice => widget.tarimaNames.length * widget.tarimaPrice.toDouble();

  double get _abono {
    if (!_isPendiente) return _totalPrice;
    return double.tryParse(_abonoCtrl.text) ?? 0.0;
  }

  double get _pendiente {
    final restante = _totalPrice - _abono;
    return restante < 0 ? 0 : restante;
  }

  Future<void> _asignar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid   = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();
    final col   = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('reservas');

    // Si está pendiente, repartir abono proporcional
    final abonoPorTarima = !_isPendiente
        ? widget.tarimaPrice.toDouble()
        : (_abono / widget.tarimaNames.length);

    for (var name in widget.tarimaNames) {
      final doc       = col.doc();
      final pagado    = !_isPendiente;
      final abonoItem = abonoPorTarima;
      final pendItem  = widget.tarimaPrice.toDouble() - abonoItem;

      batch.set(doc, {
        'tipo':      'tarima',
        'zona':      widget.zona,
        'item':      name,
        'total':     widget.tarimaPrice,
        'pagado':    pagado,
        'abono':     abonoItem,
        'pendiente': pendItem < 0 ? 0 : pendItem,
        'nombre':    _nombreCtrl.text.trim(),
        'apellido':  _apellidoCtrl.text.trim(),
        'fecha':     FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AsignacionExitosaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago de tarimas', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
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
                  Text(
                    'Tarimas: ${widget.tarimaNames.join(', ')}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total a pagar: \$${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del cliente'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingrese el nombre' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration: const InputDecoration(labelText: 'Apellido del cliente'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingrese el apellido' : null,
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
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null) return 'Número inválido';
                        if (val < 0) return 'No puede ser negativo';
                        if (val > _totalPrice) return 'Supera el total';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Restante: \$${_pendiente.toStringAsFixed(2)}'),
                    const SizedBox(height: 12),
                  ],

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
