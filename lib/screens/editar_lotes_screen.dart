// lib/screens/editar_lotes_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditarLotesScreen extends StatefulWidget {
  /// Índice de la zona de lotes (0 = zona 1, 1 = zona 2, …)
  final int zoneIndex;
  const EditarLotesScreen({Key? key, required this.zoneIndex}) : super(key: key);

  @override
  State<EditarLotesScreen> createState() => _EditarLotesScreenState();
}

class _EditarLotesScreenState extends State<EditarLotesScreen> {
  bool _loading = true;
  String? _error;

  int _tempCount = 1;
  late TextEditingController _priceController;
  final Set<int> _occupiedIndices = {};

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _loadInitial();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // 1) Cargo lista de counts (número de lotes por zona)
      final lotesDoc = await userRef.collection('config').doc('lotes').get();
      final lotesMap = lotesDoc.data() as Map<String,dynamic>? ?? {};
      final counts   = List<int>.from(lotesMap['counts'] ?? []);
      _tempCount = (widget.zoneIndex < counts.length)
          ? counts[widget.zoneIndex]
          : 1;

      // 2) Cargo precio actual (si existe)
      final priceDoc = await userRef
          .collection('config')
          .doc('prices')
          .collection('lotes')
          .doc('zona_${widget.zoneIndex + 1}')
          .get();
      final precio = (priceDoc.exists && priceDoc.data()!['precio'] is num)
          ? (priceDoc.data()!['precio'] as num).toInt()
          : 0;
      _priceController.text = precio.toString();

      // 3) Cargo los índices de lotes ya reservados (no se pueden eliminar)
      final resSnap = await userRef
          .collection('reservas')
          .where('tipo', isEqualTo: 'lote')
          .get();
      final zonaStr = (widget.zoneIndex + 1).toString();
      for (var doc in resSnap.docs) {
        final data = doc.data();
        // filtramos solo esta zona (zona puede venir como int o string)
        if (data['zona'].toString() == zonaStr) {
          final item = data['item'] as String;           // "Lote 3"
          final numStr = item.replaceAll(RegExp(r'[^0-9]'), '');
          final idx = int.tryParse(numStr);
          if (idx != null && idx > 0) {
            _occupiedIndices.add(idx - 1);
          }
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  bool get _canDecrement {
    if (_tempCount <= 1) return false;
    final newCount = _tempCount - 1;
    // no permitir si hay un lote ocupado >= newCount
    return !_occupiedIndices.any((i) => i >= newCount);
  }

  Future<void> _save() async {
    // Valido el precio
    final newPrice = int.tryParse(_priceController.text) ?? 0;

    final uid     = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // 1) Actualizar counts
    final lotesDoc = await userRef.collection('config').doc('lotes').get();
    final lotesMap = lotesDoc.data() as Map<String,dynamic>? ?? {};
    final counts   = List<int>.from(lotesMap['counts'] ?? []);
    // aseguro longitud
    while (counts.length <= widget.zoneIndex) {
      counts.add(1);
    }
    counts[widget.zoneIndex] = _tempCount;
    await userRef.collection('config').doc('lotes').set({
      'counts': counts,
    }, SetOptions(merge: true));

    // 2) Actualizar precio
    await userRef
        .collection('config')
        .doc('prices')
        .collection('lotes')
        .doc('zona_${widget.zoneIndex + 1}')
        .set({'precio': newPrice});

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error: $_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text('Editar lotes zona ${widget.zoneIndex+1}'),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // — Contador de lotes —
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Número de lotes:",
                        style: TextStyle(fontSize: 16)),
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _canDecrement
                            ? () => setState(() => _tempCount--)
                            : null,
                      ),
                      SizedBox(
                        width: 40,
                        child: Center(
                          child: Text('$_tempCount',
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () =>
                            setState(() => _tempCount++),
                      ),
                    ]),
                  ],
                ),

                const Divider(height: 32),

                // — Campo de precio —
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Precio de lote:',
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '\$',
                    border: UnderlineInputBorder(),
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
                      label: const Text('Guardar', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A0F4D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

