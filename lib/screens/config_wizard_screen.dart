// lib/screens/config_wizard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfigWizardScreen extends StatefulWidget {
  const ConfigWizardScreen({Key? key}) : super(key: key);
  @override
  State<ConfigWizardScreen> createState() => _ConfigWizardScreenState();
}

class _ConfigWizardScreenState extends State<ConfigWizardScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Paso 1
  final _formKey1 = GlobalKey<FormState>();
  int    _numTarimas    = 0;
  int    _numZonesLotes = 0;
  int    _numZonaSillas = 0;
  String _extras        = '';

  // Paso 2
  final _formKey2 = GlobalKey<FormState>();
  late List<TextEditingController> _sillasCountCtrls;
  late List<TextEditingController> _sillasRowsCtrls;
  late List<TextEditingController> _sillasColsCtrls;
  late List<TextEditingController> _lotesCtrls;
  late List<TextEditingController> _tarimasCountCtrls;
  late List<TextEditingController> _tarimasRowsCtrls;
  late List<TextEditingController> _tarimasColsCtrls;

  @override
  void initState() {
    super.initState();
    _sillasCountCtrls   = [];
    _sillasRowsCtrls    = [];
    _sillasColsCtrls    = [];
    _lotesCtrls         = [];
    _tarimasCountCtrls  = [];
    _tarimasRowsCtrls   = [];
    _tarimasColsCtrls   = [];
  }

  void _next() {
    if (_currentPage == 0) {
      if (_formKey1.currentState!.validate()) {
        _formKey1.currentState!.save();
        // preparar controllers para paso 2
        _sillasCountCtrls   = List.generate(_numZonaSillas, (_) => TextEditingController());
        _sillasRowsCtrls    = List.generate(_numZonaSillas, (_) => TextEditingController());
        _sillasColsCtrls    = List.generate(_numZonaSillas, (_) => TextEditingController());
        _lotesCtrls         = List.generate(_numZonesLotes, (_) => TextEditingController());
        _tarimasCountCtrls  = List.generate(_numTarimas, (_) => TextEditingController());
        _tarimasRowsCtrls   = List.generate(_numTarimas, (_) => TextEditingController());
        _tarimasColsCtrls   = List.generate(_numTarimas, (_) => TextEditingController());

        setState(() {});
        _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else {
      if (_formKey2.currentState!.validate()) {
        _formKey2.currentState!.save();
        _saveConfig();
      }
    }
  }

  Future<void> _saveConfig() async {
    final uid  = FirebaseAuth.instance.currentUser!.uid;
    final base = FirebaseFirestore.instance.collection('users').doc(uid);

    // Paso 1
    await base.collection('config').doc('setup').set({
      'tarimas':    _numTarimas,
      'zonesLotes': _numZonesLotes,
      'zonaSillas': _numZonaSillas,
      'extras':     _extras.split(',').map((e) => e.trim()).toList(),
    });

    // Paso 2: sillas
    if (_numZonaSillas > 0) {
      await base.collection('config').doc('sillas').set({
        'counts': _sillasCountCtrls.map((c) => int.parse(c.text)).toList(),
        'rows':   _sillasRowsCtrls.map((c) => int.parse(c.text)).toList(),
        'cols':   _sillasColsCtrls.map((c) => int.parse(c.text)).toList(),
      });
    }
    // lote
    if (_numZonesLotes > 0) {
      await base.collection('config').doc('lotes').set({
        'counts': _lotesCtrls.map((c) => int.parse(c.text)).toList(),
      });
    }
    // tarimas
    if (_numTarimas > 0) {
      await base.collection('config').doc('tarimas').set({
        'zones': List.generate(_numTarimas, (i) => {
          'count': int.parse(_tarimasCountCtrls[i].text),
          'rows':  int.parse(_tarimasRowsCtrls[i].text),
          'cols':  int.parse(_tarimasColsCtrls[i].text),
        }),
      });
    }

    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A0F4D),
        centerTitle: true,
        elevation: 0,
        title: const Text('CARNAVAL VIP',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildStep1(context),
                _buildStep2(context),
              ],
            ),
          ),
          _buildIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D0909),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                _currentPage == 0 ? 'Siguiente →' : 'Finalizar',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(BuildContext ctx) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bienvenido', style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Selecciona cuántas zonas tendrás',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey1,
                child: Column(children: [
                  _buildNumberField(ctx, 'Tarimas', (v) => _numTarimas = v),
                  _buildNumberField(ctx, 'Lotes', (v) => _numZonesLotes = v),
                  _buildNumberField(ctx, 'Sillas', (v) => _numZonaSillas = v),
                  _buildTextField(ctx, 'Extras (separados por comas)',
                      onSaved: (s) => _extras = s!),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStep2(BuildContext ctx) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Define tus zonas',
              style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // — Tarimas (ahora con filas+cols+count) —
                  if (_numTarimas > 0) ...[
                    const Text('Tarimas',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _numTarimas; i++) ...[
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tarimasCountCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Zona ${i + 1} – Asientos',
                              hintText: 'Ingresa número de asientos',
                              hintStyle: const TextStyle(color: Colors.black38),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tarimasRowsCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Filas zona ${i + 1}',
                              hintText: 'e.j. 3',
                              hintStyle: const TextStyle(color: Colors.black38),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tarimasColsCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Columnas zona ${i + 1}',
                              hintText: 'e.j. 5',
                              hintStyle: const TextStyle(color: Colors.black38),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],
                  ],
                  // — Lotes —
                  if (_numZonesLotes > 0) ...[
                    const Text('Lotes',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _numZonesLotes; i++) ...[
                      TextFormField(
                        controller: _lotesCtrls[i],
                        decoration: InputDecoration(
                          labelText: 'Zona ${i + 1}',
                          hintText: 'Ingresa número de lotes',
                          hintStyle: const TextStyle(color: Colors.black38),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  // — Sillas —
                  if (_numZonaSillas > 0) ...[
                    const Text('Sillas',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (int i = 0; i < _numZonaSillas; i++) ...[
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sillasCountCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Zona ${i + 1} – Asientos',
                              hintText: 'Total sillas',
                              hintStyle: const TextStyle(color: Colors.black38),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sillasRowsCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Filas zona ${i + 1}',
                              hintText: 'e.j. 3',
                              hintStyle: const TextStyle(color: Colors.black38),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sillasColsCtrls[i],
                            decoration: InputDecoration(
                              labelText: 'Columnas zona ${i + 1}',
                              hintText: 'e.j. 5',
                              hintStyle: const TextStyle(color: Colors.black38),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNumberField(
      BuildContext ctx, String label, ValueChanged<int> onSaved) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Ingresa tu número',
        hintStyle: const TextStyle(color: Colors.black38),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onSaved: (v) => onSaved(int.parse(v!)),
      validator: (v) =>
      (v == null || int.tryParse(v) == null) ? 'Requerido' : null,
    );
  }

  Widget _buildTextField(
      BuildContext ctx, String label, {void Function(String?)? onSaved}) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Ingresa los nombres',
        hintStyle: const TextStyle(color: Colors.black38),
        isDense: true,
      ),
      onSaved: onSaved,
    );
  }

  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          2,
              (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == i ? 12 : 8,
            height: _currentPage == i ? 12 : 8,
            decoration: BoxDecoration(
              color: _currentPage == i
                  ? const Color(0xFF5A0F4D)
                  : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
