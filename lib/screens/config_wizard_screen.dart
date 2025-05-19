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

  // Listas para rastrear zonas ineficientes
  final List<int> _sillasWasteful = [];
  final List<int> _tarimasWasteful = [];

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

        // Verificar que al menos una zona esté configurada
        if (_numTarimas == 0 && _numZonesLotes == 0 && _numZonaSillas == 0 && _extras.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes configurar al menos un tipo de zona')),
          );
          return;
        }

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
      // Limpiar las listas de zonas ineficientes antes de volver a comprobar
      _sillasWasteful.clear();
      _tarimasWasteful.clear();

      if (_formKey2.currentState!.validate()) {
        // Comprobaciones explícitas de eficiencia
        bool hasInefficiencyWarning = false;

        // Verificar zonas de sillas
        for (int i = 0; i < _numZonaSillas; i++) {
          final seatsCount = int.tryParse(_sillasCountCtrls[i].text) ?? 0;
          final rows = int.tryParse(_sillasRowsCtrls[i].text) ?? 0;
          final cols = int.tryParse(_sillasColsCtrls[i].text) ?? 0;

          if (rows > 0 && cols > 0) {
            // Verificar que count no exceda rows*cols
            if (seatsCount > rows * cols) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Zona ${i+1} de sillas: El número de sillas no puede exceder filas × columnas')),
              );
              return;
            }

            // Comprobar eficiencia
            final totalSlots = rows * cols;
            final utilizationRate = seatsCount / totalSlots;

            if (utilizationRate < 0.5) {
              _sillasWasteful.add(i);
              hasInefficiencyWarning = true;
            }
          }
        }

        // Verificar zonas de tarimas
        for (int i = 0; i < _numTarimas; i++) {
          final tarimCount = int.tryParse(_tarimasCountCtrls[i].text) ?? 0;
          final rows = int.tryParse(_tarimasRowsCtrls[i].text) ?? 0;
          final cols = int.tryParse(_tarimasColsCtrls[i].text) ?? 0;

          if (rows > 0 && cols > 0) {
            // Verificar que count no exceda rows*cols
            if (tarimCount > rows * cols) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Zona ${i+1} de tarimas: El número de tarimas no puede exceder filas × columnas')),
              );
              return;
            }

            // Comprobar eficiencia
            final totalSlots = rows * cols;
            final utilizationRate = tarimCount / totalSlots;

            if (utilizationRate < 0.5) {
              _tarimasWasteful.add(i);
              hasInefficiencyWarning = true;
            }
          }
        }

        // Si hay alguna advertencia de ineficiencia, mostrar el diálogo
        if (hasInefficiencyWarning) {
          _showWastefulWarning().then((shouldContinue) {
            if (shouldContinue) {
              _formKey2.currentState!.save();
              _saveConfig();
            }
          });
        } else {
          // Si no hay advertencias, continuar normalmente
          _formKey2.currentState!.save();
          _saveConfig();
        }
      }
    }
  }

  // Validador para números positivos
  String? _validatePositiveNumber(String? v) {
    if (v == null || v.isEmpty) return 'Requerido';

    final number = int.tryParse(v);
    if (number == null) return 'Debe ser un número entero';
    if (number <= 0) return 'Debe ser mayor que 0';

    return null;
  }

  // Validador para números en el paso 1 (puede ser 0 o positivo)
  String? _validateNumberPaso1(String? v) {
    if (v == null || v.isEmpty) return 'Requerido';

    final number = int.tryParse(v);
    if (number == null) return 'Debe ser un número entero';
    if (number < 0) return 'No puede ser negativo';

    return null;
  }

  // Mostrar advertencia de configuración ineficiente
  Future<bool> _showWastefulWarning() async {
    List<String> warnings = [];

    for (var idx in _sillasWasteful) {
      final seatsCount = int.tryParse(_sillasCountCtrls[idx].text) ?? 0;
      final rows = int.tryParse(_sillasRowsCtrls[idx].text) ?? 0;
      final cols = int.tryParse(_sillasColsCtrls[idx].text) ?? 0;
      final totalSlots = rows * cols;
      final emptySlots = totalSlots - seatsCount;
      final wastePct = (emptySlots / totalSlots * 100).toStringAsFixed(1);

      warnings.add('Zona ${idx+1} de sillas: $emptySlots/$totalSlots espacios vacíos ($wastePct%)');
    }

    for (var idx in _tarimasWasteful) {
      final tarimCount = int.tryParse(_tarimasCountCtrls[idx].text) ?? 0;
      final rows = int.tryParse(_tarimasRowsCtrls[idx].text) ?? 0;
      final cols = int.tryParse(_tarimasColsCtrls[idx].text) ?? 0;
      final totalSlots = rows * cols;
      final emptySlots = totalSlots - tarimCount;
      final wastePct = (emptySlots / totalSlots * 100).toStringAsFixed(1);

      warnings.add('Zona ${idx+1} de tarimas: $emptySlots/$totalSlots espacios vacíos ($wastePct%)');
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Configuración ineficiente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Las siguientes zonas tienen muchos espacios vacíos:'),
              const SizedBox(height: 8),
              ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $w'),
              )),
              const SizedBox(height: 12),
              const Text('¿Estás seguro de que quieres continuar con esta configuración?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A0F4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _saveConfig() async {
    final uid  = FirebaseAuth.instance.currentUser!.uid;
    final base = FirebaseFirestore.instance.collection('users').doc(uid);

    // Lista de extras correctamente procesada
    List<String> extrasList = [];
    if (_extras.trim().isNotEmpty) {
      extrasList = _extras.split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Paso 1
    await base.collection('config').doc('setup').set({
      'tarimas':    _numTarimas,
      'zonesLotes': _numZonesLotes,
      'zonaSillas': _numZonaSillas,
      'extras':     extrasList,
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
                  _buildNumberFieldPaso1(ctx, 'Tarimas', (v) => _numTarimas = v),
                  _buildNumberFieldPaso1(ctx, 'Lotes', (v) => _numZonesLotes = v),
                  _buildNumberFieldPaso1(ctx, 'Sillas', (v) => _numZonaSillas = v),
                  _buildTextField(ctx, 'Extras (separados por comas)',
                      onSaved: (s) => _extras = s ?? ''),
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
                            validator: _validatePositiveNumber,
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
                            validator: _validatePositiveNumber,
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
                            validator: _validatePositiveNumber,
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
                        validator: _validatePositiveNumber,
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
                            validator: _validatePositiveNumber,
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
                            validator: _validatePositiveNumber,
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
                            validator: _validatePositiveNumber,
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

  Widget _buildNumberFieldPaso1(
      BuildContext ctx, String label, ValueChanged<int> onSaved) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Ingresa tu número',
        hintStyle: const TextStyle(color: Colors.black38),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onSaved: (v) => onSaved(int.tryParse(v!) ?? 0),
      validator: _validateNumberPaso1,
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