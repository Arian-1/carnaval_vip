// lib/screens/config_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({Key? key}) : super(key: key);
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  int _numTarimas    = 0;
  int _numLotes      = 0;
  int _sillasPorLote = 0;
  String _extras     = '';

  double _widthSilla   = 50;
  double _heightSilla  = 50;
  double _widthLote    = 100;
  double _heightLote   = 100;
  double _widthTarima  = 100;
  double _heightTarima = 100;
  double _widthExtra   = 50;
  double _heightExtra  = 50;

  Future<void> _saveConfig() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

    // 1) Guardar datos de configuración y tamaños iniciales
    await userDoc.set({
      'numTarimas': _numTarimas,
      'numLotes': _numLotes,
      'sillasPorLote': _sillasPorLote,
      'extras': _extras.split(',').map((e) => e.trim()).toList(),
      'defaultSizes': {
        'silla':  {'width': _widthSilla,  'height': _heightSilla},
        'lote':   {'width': _widthLote,   'height': _heightLote},
        'tarima': {'width': _widthTarima, 'height': _heightTarima},
        'extra':  {'width': _widthExtra,  'height': _heightExtra},
      },
    }, SetOptions(merge: true));

    // 2) Recuperar los tamaños guardados
    final snapshot = await userDoc.get();
    final cfg     = snapshot.data()!;
    final ds      = cfg['defaultSizes'] as Map<String, dynamic>;
    final sSz     = ds['silla']  as Map<String, dynamic>;
    final lSz     = ds['lote']   as Map<String, dynamic>;
    final tSz     = ds['tarima'] as Map<String, dynamic>;
    final eSz     = ds['extra']  as Map<String, dynamic>;

    // 3) Referencias a subcolecciones
    final lotsCol    = userDoc.collection('lots');
    final chairsCol  = userDoc.collection('chairs');
    final tarimasCol = userDoc.collection('tarimas');
    final extrasCol  = userDoc.collection('extras');

    // 4) Generar lotes y sillas
    for (int i = 0; i < _numLotes; i++) {
      final lotRef = await lotsCol.add({
        'name': 'Lote ${i + 1}',
        'seatCount': _sillasPorLote,
        'position': {'x': 0.0, 'y': 0.0},
        'size': lSz,
      });
      for (int j = 0; j < _sillasPorLote; j++) {
        final seatId = '${String.fromCharCode(65 + i)}${j + 1}';
        await chairsCol.add({
          'name': seatId,
          'lotId': lotRef.id,
          'position': {'x': 0.0, 'y': 0.0},
          'size': sSz,
          'status': 'libre',
        });
      }
    }

    // 5) Generar tarimas
    for (int i = 0; i < _numTarimas; i++) {
      await tarimasCol.add({
        'name': 'Tarima ${i + 1}',
        'position': {'x': 0.0, 'y': 0.0},
        'size': tSz,
      });
    }

    // 6) Generar extras
    for (var tipo in _extras.split(',').map((e) => e.trim())) {
      await extrasCol.add({
        'type': tipo,
        'position': {'x': 0.0, 'y': 0.0},
        'size': eSz,
      });
    }

    // 7) Navegar al Home
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar croquis')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Número de elementos
              TextFormField(
                decoration: const InputDecoration(labelText: 'Número de tarimas'),
                keyboardType: TextInputType.number,
                onSaved: (v) => _numTarimas    = int.parse(v!),
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Requerido' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Número de lotes'),
                keyboardType: TextInputType.number,
                onSaved: (v) => _numLotes      = int.parse(v!),
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Requerido' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Sillas por lote'),
                keyboardType: TextInputType.number,
                onSaved: (v) => _sillasPorLote = int.parse(v!),
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Requerido' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Extras (separados por comas)',
                  helperText: 'ej. Baños, Barra, Escenario',
                ),
                onSaved: (v) => _extras = v ?? '',
              ),
              const SizedBox(height: 20),

              const Divider(),
              const Text('Tamaños iniciales', style: TextStyle(fontWeight: FontWeight.bold)),
              // Tamaños silla
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ancho silla'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '50',
                onSaved: (v) => _widthSilla  = double.parse(v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Alto silla'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '50',
                onSaved: (v) => _heightSilla = double.parse(v!),
              ),
              // Tamaños lote
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ancho lote'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '100',
                onSaved: (v) => _widthLote   = double.parse(v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Alto lote'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '100',
                onSaved: (v) => _heightLote  = double.parse(v!),
              ),
              // Tamaños tarima
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ancho tarima'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '100',
                onSaved: (v) => _widthTarima  = double.parse(v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Alto tarima'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '100',
                onSaved: (v) => _heightTarima = double.parse(v!),
              ),
              // Tamaños extra
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ancho extra'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '50',
                onSaved: (v) => _widthExtra   = double.parse(v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Alto extra'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                initialValue: '50',
                onSaved: (v) => _heightExtra  = double.parse(v!),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    _saveConfig();
                  }
                },
                child: const Text('Guardar configuración'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



