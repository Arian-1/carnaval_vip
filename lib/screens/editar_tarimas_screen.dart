// lib/screens/editar_tarimas_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditarTarimasScreen extends StatefulWidget {
  final int zoneIndex;
  const EditarTarimasScreen({Key? key, required this.zoneIndex})
      : super(key: key);

  @override
  State<EditarTarimasScreen> createState() => _EditarTarimasScreenState();
}

class _EditarTarimasScreenState extends State<EditarTarimasScreen> {
  bool _loading = true;
  String? _error;

  late int _tempCount;
  late int _tempRows;
  late int _tempCols;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController();
    _loadInitial();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // 1) Cargo configuración de tarimas
      final doc  = await userRef.collection('config').doc('tarimas').get();
      final data = doc.data() as Map<String, dynamic>? ?? {};

      // Extraigo el mapa 'zones'
      final rawZones = data['zones'];
      final Map<String, dynamic> zones = {};
      if (rawZones is Map) {
        zones.addAll(Map<String, dynamic>.from(rawZones));
      } else if (rawZones is List) {
        for (var i = 0; i < rawZones.length; i++) {
          if (rawZones[i] is Map) {
            zones['$i'] = Map<String, dynamic>.from(rawZones[i]);
          }
        }
      }

      final key = widget.zoneIndex.toString();
      final z   = zones[key] as Map<String,dynamic>? ?? {};

      _tempRows  = (z['rows']  is int) ? z['rows']  as int : 1;
      _tempCols  = (z['cols']  is int) ? z['cols']  as int : 1;
      _tempCount = (z['count'] is int) ? z['count'] as int : (_tempRows * _tempCols);

      // 2) Cargo precio de tarimas
      final pSnap = await userRef
          .collection('config')
          .doc('prices')
          .collection('tarimas')
          .doc('zona_${widget.zoneIndex + 1}')
          .get();
      if (pSnap.exists && pSnap.data()!.containsKey('precio')) {
        _priceCtrl.text = pSnap.data()!['precio'].toString();
      } else {
        _priceCtrl.text = '0';
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_tempCount > _tempRows * _tempCols) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El total de tarimas no puede exceder filas × columnas.')),
      );
      return;
    }

    final uid      = FirebaseAuth.instance.currentUser!.uid;
    final tarRef   = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('config')
        .doc('tarimas');

    // 1) Leo el mapa actual de zones
    final snap     = await tarRef.get();
    final data     = snap.data() as Map<String, dynamic>? ?? {};
    final rawZones = data['zones'];
    final Map<String, dynamic> zones = {};

    if (rawZones is Map) {
      zones.addAll(Map<String, dynamic>.from(rawZones));
    } else if (rawZones is List) {
      for (var i = 0; i < rawZones.length; i++) {
        if (rawZones[i] is Map) {
          zones['$i'] = Map<String, dynamic>.from(rawZones[i]);
        }
      }
    }

    // 2) Actualizo sólo mi zona
    final key = widget.zoneIndex.toString();
    zones[key] = {
      'rows':  _tempRows,
      'cols':  _tempCols,
      'count': _tempCount,
    };

    // 3) Escribo de vuelta todo el mapa zones (merge evita sobreescribir otros campos)
    await tarRef.set({'zones': zones}, SetOptions(merge: true));

    // 4) Guardar precio
    final price = int.tryParse(_priceCtrl.text) ?? 0;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('config')
        .doc('prices')
        .collection('tarimas')
        .doc('zona_${widget.zoneIndex + 1}')
        .set({'precio': price});

    Navigator.pop(context);
  }

  Widget _buildCounter(String label, int value, VoidCallback inc, VoidCallback dec) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: dec),
          SizedBox(width: 40, child: Center(child: Text('$value'))),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: inc),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Text('Editar tarimas zona ${widget.zoneIndex + 1}'),
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCounter(
                  'Número de filas',
                  _tempRows,
                      () => setState(() => _tempRows++),
                      () { if (_tempRows>1) setState(() => _tempRows--); },
                ),
                const SizedBox(height: 12),
                _buildCounter(
                  'Número de columnas',
                  _tempCols,
                      () => setState(() => _tempCols++),
                      () { if (_tempCols>1) setState(() => _tempCols--); },
                ),
                const SizedBox(height: 12),
                _buildCounter(
                  'Total de tarimas',
                  _tempCount,
                      () => setState(() => _tempCount++),
                      () { if (_tempCount>1) setState(() => _tempCount--); },
                ),
                const Divider(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Precio (\$):',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _priceCtrl,
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
                      label: const Text('Guardar',  style: TextStyle(color: Colors.white)),
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
