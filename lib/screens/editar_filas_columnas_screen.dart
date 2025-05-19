// lib/screens/editar_filas_columnas_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditarFilasColumnasScreen extends StatefulWidget {
  final int zoneIndex;
  const EditarFilasColumnasScreen({Key? key, required this.zoneIndex})
      : super(key: key);

  @override
  State<EditarFilasColumnasScreen> createState() =>
      _EditarFilasColumnasScreenState();
}

class _EditarFilasColumnasScreenState
    extends State<EditarFilasColumnasScreen> {
  bool _loading = true;
  String? _error;

  late int _tempSeatCount;
  late int _tempRowCount;
  late int _tempColCount;
  final List<TextEditingController> _priceCtrls = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    for (var c in _priceCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      final doc = await userRef.collection('config').doc('sillas').get();
      final data = doc.data()!;
      final counts = List<int>.from(data['counts'] ?? []);
      final rows   = List<int>.from(data['rows']   ?? []);
      final cols   = List<int>.from(data['cols']   ?? []);

      final zi = widget.zoneIndex;
      _tempSeatCount = (zi < counts.length) ? counts[zi] : 0;
      _tempRowCount  = (zi < rows.length)   ? rows[zi]   : 1;
      _tempColCount  = (zi < cols.length)   ? cols[zi]   : 1;

      // precios
      final pdoc = await userRef
          .collection('config')
          .doc('prices')
          .collection('sillas')
          .doc('zona_${zi+1}')
          .get();
      final raw = pdoc.exists
          ? List<dynamic>.from(pdoc.data()!['filaPrecios'] ?? [])
          : <dynamic>[];

      _priceCtrls.clear();
      for (var r = 0; r < _tempRowCount; r++) {
        final v = (r < raw.length && raw[r] is int) ? raw[r] as int : 0;
        _priceCtrls.add(TextEditingController(text: v.toString()));
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _syncCtrls() {
    while (_priceCtrls.length < _tempRowCount) {
      _priceCtrls.add(TextEditingController(text: '0'));
    }
    while (_priceCtrls.length > _tempRowCount) {
      _priceCtrls.removeLast().dispose();
    }
  }

  Future<void> _save() async {
    // Validaciones de valores mínimos
    if (_tempSeatCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El número de sillas debe ser mayor a 0.')),
      );
      return;
    }

    if (_tempRowCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El número de filas debe ser mayor a 0.')),
      );
      return;
    }

    if (_tempColCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El número de columnas debe ser mayor a 0.')),
      );
      return;
    }

    // Validación de la relación sillas vs. filas×columnas
    if (_tempSeatCount > _tempRowCount * _tempColCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'El total de sillas no puede exceder filas × columnas.'),
        ),
      );
      return;
    }

    final uid     = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // leo arrays
    final doc    = await userRef.collection('config').doc('sillas').get();
    final data   = doc.data()!;
    final counts = List<int>.from(data['counts'] ?? []);
    final rows   = List<int>.from(data['rows']   ?? []);
    final cols   = List<int>.from(data['cols']   ?? []);

    final zi = widget.zoneIndex;
    while (counts.length <= zi) counts.add(0);
    while (rows.length   <= zi) rows.add(1);
    while (cols.length   <= zi) cols.add(1);

    counts[zi] = _tempSeatCount;
    rows[zi]   = _tempRowCount;
    cols[zi]   = _tempColCount;

    // guardo merge para no pisar otras zonas
    await userRef.collection('config').doc('sillas').set({
      'counts': counts,
      'rows':   rows,
      'cols':   cols,
    }, SetOptions(merge: true));

    // precios por fila
    _syncCtrls();
    final precios = _priceCtrls.map((c) => int.tryParse(c.text) ?? 0).toList();
    await userRef
        .collection('config')
        .doc('prices')
        .collection('sillas')
        .doc('zona_${zi+1}')
        .set({ 'filaPrecios': precios });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    _syncCtrls();

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text('Editar sillas zona ${widget.zoneIndex + 1}'),
        backgroundColor: const Color(0xFF5A0F4D),

        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildCounterRow(
                  'Número de sillas', _tempSeatCount,
                      () => setState(() => _tempSeatCount++),
                      () { if (_tempSeatCount>1) setState(() => _tempSeatCount--); }
              ),
              const SizedBox(height: 16),
              _buildCounterRow(
                  'Número de filas', _tempRowCount,
                      () => setState(() {
                    _tempRowCount++;
                    _syncCtrls();
                  }),
                      () { if (_tempRowCount>1) setState(() {
                    _tempRowCount--;
                    _syncCtrls();
                  }); }
              ),
              const SizedBox(height: 16),
              _buildCounterRow(
                  'Número de columnas', _tempColCount,
                      () => setState(() => _tempColCount++),
                      () { if (_tempColCount>1) setState(() => _tempColCount--); }
              ),

              const Divider(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Asignar precios:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              for (var r = 0; r < _tempRowCount; r++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: _priceCtrls[r],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Fila ${String.fromCharCode(65 + r)}',
                      prefixText: '\$',
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Regresar'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Guardar',  style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A0F4D),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterRow(
      String label,
      int value,
      VoidCallback onInc,
      VoidCallback onDec,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: onDec),
          SizedBox(width: 40, child: Center(child: Text('$value'))),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onInc),
        ]),
      ],
    );
  }
}


